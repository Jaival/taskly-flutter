// Security rules tests. Every rule in ../firestore.rules should have a test
// that proves it allows what it should AND one that proves it blocks what it
// shouldn't. Run with `npm test` (starts the emulator for you).

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  arrayRemove,
  arrayUnion,
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  setLogLevel,
  Timestamp,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

// alice owns project p1, bob edits it, carol views it. dave is a stranger.
// erin has a pending invite to p1.
const users = {
  alice: 'alice@example.com',
  bob: 'bob@example.com',
  carol: 'carol@example.com',
  dave: 'dave@example.com',
  erin: 'erin@example.com',
};

let env;

/** Firestore as the named user, with a verified email unless told otherwise. */
function as(uid, { verified = true } = {}) {
  return env
    .authenticatedContext(uid, { email: users[uid], email_verified: verified })
    .firestore();
}

const signedOut = () => env.unauthenticatedContext().firestore();

/** Writes test data with the rules switched off. */
function seed(write) {
  return env.withSecurityRulesDisabled((context) => write(context.firestore()));
}

const project = (overrides = {}) => ({
  ownerId: 'alice',
  name: 'Launch',
  description: '',
  priority: 'high',
  status: 'notStarted',
  memberIds: ['alice'],
  roles: { alice: 'owner' },
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...overrides,
});

const task = (overrides = {}) => ({
  ownerId: 'alice',
  title: 'Write copy',
  description: '',
  priority: 'medium',
  status: 'notStarted',
  assigneeId: null,
  dueDate: null,
  order: 0,
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...overrides,
});

const erinInviteId = 'p1_erin@example.com';

const invite = (overrides = {}) => ({
  projectId: 'p1',
  projectName: 'Launch',
  email: 'erin@example.com',
  role: 'viewer',
  invitedBy: 'alice',
  status: 'pending',
  createdAt: serverTimestamp(),
  ...overrides,
});

before(async () => {
  // Denied writes are expected here; don't log each one as a warning.
  setLogLevel('error');
  env = await initializeTestEnvironment({
    projectId: 'demo-taskly',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await seed(async (db) => {
    await setDoc(
      doc(db, 'projects/p1'),
      project({
        memberIds: ['alice', 'bob', 'carol'],
        roles: { alice: 'owner', bob: 'editor', carol: 'viewer' },
      }),
    );
    await setDoc(doc(db, 'projects/p1/tasks/t1'), task({ assigneeId: 'carol' }));
    await setDoc(doc(db, 'tasks/personal1'), task({ ownerId: 'dave' }));
    await setDoc(doc(db, 'invites', erinInviteId), invite());
    await setDoc(doc(db, 'users/alice'), {
      displayName: 'Alice',
      email: users.alice,
      photoUrl: null,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
  });
});

describe('users', () => {
  test('a user can create their own profile', async () => {
    await assertSucceeds(
      setDoc(doc(as('bob'), 'users/bob'), {
        displayName: 'Bob',
        email: users.bob,
        photoUrl: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test("a user can't write someone else's profile", async () => {
    await assertFails(
      setDoc(doc(as('bob'), 'users/dave'), {
        displayName: 'Dave',
        email: users.bob,
        photoUrl: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test("the profile email must match the account's", async () => {
    await assertFails(
      setDoc(doc(as('bob'), 'users/bob'), {
        displayName: 'Bob',
        email: 'someone-else@example.com',
        photoUrl: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('signed-in users can read one profile but not list them all', async () => {
    await assertSucceeds(getDoc(doc(as('dave'), 'users/alice')));
    await assertFails(getDocs(collection(as('dave'), 'users')));
  });

  test("signed-out visitors can't read profiles", async () => {
    await assertFails(getDoc(doc(signedOut(), 'users/alice')));
  });
});

describe('projects: create', () => {
  test('a user can create a project they own', async () => {
    await assertSucceeds(setDoc(doc(as('dave'), 'projects/new'), project({
      ownerId: 'dave',
      memberIds: ['dave'],
      roles: { dave: 'owner' },
    })));
  });

  test("a user can't create a project owned by someone else", async () => {
    await assertFails(setDoc(doc(as('dave'), 'projects/new'), project()));
  });

  test("a new project can't start with other members", async () => {
    await assertFails(setDoc(doc(as('alice'), 'projects/new'), project({
      memberIds: ['alice', 'dave'],
      roles: { alice: 'owner', dave: 'editor' },
    })));
  });

  test('timestamps must come from the server', async () => {
    await assertFails(setDoc(doc(as('alice'), 'projects/new'), project({
      createdAt: Timestamp.now(),
    })));
  });

  test('invalid data is rejected', async () => {
    const db = as('alice');
    await assertFails(setDoc(doc(db, 'projects/a'), project({ name: '' })));
    await assertFails(setDoc(doc(db, 'projects/b'), project({ priority: 'urgent' })));
    await assertFails(setDoc(doc(db, 'projects/c'), project({ status: 'done' })));
    await assertFails(setDoc(doc(db, 'projects/d'), project({ extra: true })));
    await assertFails(setDoc(doc(db, 'projects/e'), project({ name: 'x'.repeat(101) })));
  });
});

describe('projects: read', () => {
  test('members can read the project, others cannot', async () => {
    await assertSucceeds(getDoc(doc(as('carol'), 'projects/p1')));
    await assertFails(getDoc(doc(as('dave'), 'projects/p1')));
    await assertFails(getDoc(doc(signedOut(), 'projects/p1')));
  });

  test('"my projects" works only when filtered by membership', async () => {
    const db = as('bob');
    await assertSucceeds(
      getDocs(query(collection(db, 'projects'), where('memberIds', 'array-contains', 'bob'))),
    );
    await assertFails(getDocs(collection(db, 'projects')));
  });
});

describe('projects: update', () => {
  test('an editor can change the content', async () => {
    await assertSucceeds(updateDoc(doc(as('bob'), 'projects/p1'), {
      name: 'Launch v2',
      updatedAt: serverTimestamp(),
    }));
  });

  test("an update must refresh updatedAt", async () => {
    await assertFails(updateDoc(doc(as('bob'), 'projects/p1'), { name: 'Launch v2' }));
  });

  test("a viewer can't change the project", async () => {
    await assertFails(updateDoc(doc(as('carol'), 'projects/p1'), {
      name: 'Mine now',
      updatedAt: serverTimestamp(),
    }));
  });

  test("an editor can't change roles", async () => {
    await assertFails(updateDoc(doc(as('bob'), 'projects/p1'), {
      'roles.carol': 'editor',
      updatedAt: serverTimestamp(),
    }));
  });

  test('the owner can change a role and remove a member', async () => {
    await assertSucceeds(updateDoc(doc(as('alice'), 'projects/p1'), {
      'roles.carol': 'editor',
      updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(doc(as('alice'), 'projects/p1'), {
      memberIds: arrayRemove('bob'),
      'roles.bob': deleteField(),
      updatedAt: serverTimestamp(),
    }));
  });

  test("the owner can't add a member without an invite", async () => {
    await assertFails(updateDoc(doc(as('alice'), 'projects/p1'), {
      memberIds: arrayUnion('dave'),
      'roles.dave': 'viewer',
      updatedAt: serverTimestamp(),
    }));
  });

  test("the owner can't create a second owner or give ownership away", async () => {
    await assertFails(updateDoc(doc(as('alice'), 'projects/p1'), {
      'roles.bob': 'owner',
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(as('alice'), 'projects/p1'), {
      ownerId: 'bob',
      'roles.alice': 'editor',
      'roles.bob': 'owner',
      updatedAt: serverTimestamp(),
    }));
  });

  test('a member can leave, but the owner cannot', async () => {
    await assertSucceeds(updateDoc(doc(as('carol'), 'projects/p1'), {
      memberIds: arrayRemove('carol'),
      'roles.carol': deleteField(),
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(as('alice'), 'projects/p1'), {
      memberIds: arrayRemove('alice'),
      'roles.alice': deleteField(),
      updatedAt: serverTimestamp(),
    }));
  });

  test("a member can't remove someone else", async () => {
    await assertFails(updateDoc(doc(as('carol'), 'projects/p1'), {
      memberIds: arrayRemove('bob'),
      'roles.bob': deleteField(),
      updatedAt: serverTimestamp(),
    }));
  });
});

describe('projects: delete', () => {
  test('only the owner can delete a project', async () => {
    await assertFails(deleteDoc(doc(as('bob'), 'projects/p1')));
    await assertSucceeds(deleteDoc(doc(as('alice'), 'projects/p1')));
  });
});

describe('project tasks', () => {
  test('members can read tasks, others cannot', async () => {
    await assertSucceeds(getDocs(collection(as('carol'), 'projects/p1/tasks')));
    await assertFails(getDocs(collection(as('dave'), 'projects/p1/tasks')));
  });

  test('editors can create tasks, viewers cannot', async () => {
    await assertSucceeds(setDoc(doc(as('bob'), 'projects/p1/tasks/new'), task({ ownerId: 'bob' })));
    await assertFails(setDoc(doc(as('carol'), 'projects/p1/tasks/new'), task({ ownerId: 'carol' })));
  });

  test('tasks can only be assigned to project members', async () => {
    const db = as('bob');
    await assertSucceeds(setDoc(doc(db, 'projects/p1/tasks/a'), task({ ownerId: 'bob', assigneeId: 'carol' })));
    await assertFails(setDoc(doc(db, 'projects/p1/tasks/b'), task({ ownerId: 'bob', assigneeId: 'dave' })));
  });

  test('a viewer can update the status of a task assigned to them, and nothing else', async () => {
    const db = as('carol');
    await assertSucceeds(updateDoc(doc(db, 'projects/p1/tasks/t1'), {
      status: 'inProgress',
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(db, 'projects/p1/tasks/t1'), {
      title: 'Renamed',
      updatedAt: serverTimestamp(),
    }));
  });

  test('editors can delete tasks, viewers cannot', async () => {
    await assertFails(deleteDoc(doc(as('carol'), 'projects/p1/tasks/t1')));
    await assertSucceeds(deleteDoc(doc(as('bob'), 'projects/p1/tasks/t1')));
  });
});

describe('personal tasks', () => {
  test('only the owner can read their tasks', async () => {
    await assertSucceeds(getDoc(doc(as('dave'), 'tasks/personal1')));
    await assertFails(getDoc(doc(as('alice'), 'tasks/personal1')));
  });

  test('listing works when filtered by owner', async () => {
    const db = as('dave');
    await assertSucceeds(getDocs(query(collection(db, 'tasks'), where('ownerId', '==', 'dave'))));
    await assertFails(getDocs(collection(db, 'tasks')));
  });

  test("a user can't create a task for someone else", async () => {
    await assertFails(setDoc(doc(as('dave'), 'tasks/new'), task({ ownerId: 'alice' })));
    await assertSucceeds(setDoc(doc(as('dave'), 'tasks/new'), task({ ownerId: 'dave' })));
  });
});

describe('invites', () => {
  test('the owner can invite someone', async () => {
    await assertSucceeds(setDoc(
      doc(as('alice'), 'invites/p1_dave@example.com'),
      invite({ email: 'dave@example.com', role: 'editor' }),
    ));
  });

  test("an editor can't invite people", async () => {
    await assertFails(setDoc(
      doc(as('bob'), 'invites/p1_dave@example.com'),
      invite({ email: 'dave@example.com', invitedBy: 'bob' }),
    ));
  });

  test('the invite ID must be {projectId}_{email}', async () => {
    await assertFails(setDoc(
      doc(as('alice'), 'invites/something-else'),
      invite({ email: 'dave@example.com' }),
    ));
  });

  test("nobody can be invited as an owner", async () => {
    await assertFails(setDoc(
      doc(as('alice'), 'invites/p1_dave@example.com'),
      invite({ email: 'dave@example.com', role: 'owner' }),
    ));
  });

  test('the invitee can see it only with a verified email', async () => {
    await assertSucceeds(getDoc(doc(as('erin'), 'invites', erinInviteId)));
    await assertFails(getDoc(doc(as('erin', { verified: false }), 'invites', erinInviteId)));
    await assertFails(getDoc(doc(as('dave'), 'invites', erinInviteId)));
  });

  test('the invitee can list their invites by email', async () => {
    const db = as('erin');
    await assertSucceeds(
      getDocs(query(collection(db, 'invites'), where('email', '==', users.erin))),
    );
  });
});

describe('joining a project with an invite', () => {
  /** Accepts the invite and joins p1 in one atomic batch, like the app will. */
  function join(db, { role = 'viewer', accept = true } = {}) {
    const batch = writeBatch(db);
    if (accept) batch.update(doc(db, 'invites', erinInviteId), { status: 'accepted' });
    batch.update(doc(db, 'projects/p1'), {
      memberIds: arrayUnion('erin'),
      [`roles.erin`]: role,
      updatedAt: serverTimestamp(),
    });
    return batch.commit();
  }

  test('the invitee joins with the invited role', async () => {
    const db = as('erin');
    await assertSucceeds(join(db));
    await assertSucceeds(getDoc(doc(db, 'projects/p1')));
  });

  test("joining without accepting the invite fails", async () => {
    await assertFails(join(as('erin'), { accept: false }));
  });

  test("the invitee can't pick a better role than invited", async () => {
    await assertFails(join(as('erin'), { role: 'editor' }));
  });

  test("an unverified email can't claim the invite", async () => {
    await assertFails(join(as('erin', { verified: false })));
  });

  test("someone without an invite can't join", async () => {
    const db = as('dave');
    const batch = writeBatch(db);
    batch.update(doc(db, 'projects/p1'), {
      memberIds: arrayUnion('dave'),
      'roles.dave': 'viewer',
      updatedAt: serverTimestamp(),
    });
    await assertFails(batch.commit());
  });

  test('an invite works only once', async () => {
    const db = as('erin');
    await assertSucceeds(join(db));
    await assertSucceeds(updateDoc(doc(db, 'projects/p1'), {
      memberIds: arrayRemove('erin'),
      'roles.erin': deleteField(),
      updatedAt: serverTimestamp(),
    }));
    await assertFails(join(db));
    // The invite already says "accepted", so skipping the invite update must
    // not work either.
    await assertFails(join(db, { accept: false }));
  });
});

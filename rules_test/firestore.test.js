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
  orderBy,
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

const activityPath = 'projects/p1/tasks/t1/activity';

const entry = (overrides = {}) => ({
  kind: 'comment',
  authorId: 'carol',
  authorName: 'Carol',
  value: 'Looks good',
  createdAt: serverTimestamp(),
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

describe('retried deletes', () => {
  // The SDK retries a delete whose acknowledgement was lost. The retry must
  // succeed, or the app rolls back its local delete and shows a ghost.
  test('deleting a document that is already gone succeeds', async () => {
    await assertSucceeds(deleteDoc(doc(as('alice'), 'projects/gone')));
    await assertSucceeds(deleteDoc(doc(as('bob'), 'projects/p1/tasks/gone')));
    await assertSucceeds(deleteDoc(doc(as('dave'), 'tasks/gone')));
    await assertSucceeds(deleteDoc(doc(as('alice'), 'invites/gone')));
  });

  test("signed-out visitors still can't delete anything", async () => {
    await assertFails(deleteDoc(doc(signedOut(), 'projects/gone')));
    await assertFails(deleteDoc(doc(signedOut(), 'tasks/gone')));
  });

  test("an existing document still needs permission", async () => {
    await assertFails(deleteDoc(doc(as('bob'), 'projects/p1')));
    await assertFails(deleteDoc(doc(as('alice'), 'tasks/personal1')));
    await assertFails(deleteDoc(doc(as('carol'), 'projects/p1/tasks/t1')));
  });
});

describe('project tasks', () => {
  test('members can read tasks, others cannot', async () => {
    await assertSucceeds(getDocs(collection(as('carol'), 'projects/p1/tasks')));
    await assertFails(getDocs(collection(as('dave'), 'projects/p1/tasks')));
  });

  test("the Tasks page's query: a member's assigned tasks, in order", async () => {
    const assigned = (db, uid) => query(
      collection(db, 'projects/p1/tasks'),
      where('assigneeId', '==', uid),
      orderBy('order'),
    );
    await assertSucceeds(getDocs(assigned(as('carol'), 'carol')));
    await assertFails(getDocs(assigned(as('dave'), 'dave')));
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

  test('a task assigned to someone who left can still be edited', async () => {
    await seed((db) => setDoc(doc(db, 'projects/p1/tasks/t2'), task({ assigneeId: 'zed' })));
    const db = as('bob');
    await assertSucceeds(updateDoc(doc(db, 'projects/p1/tasks/t2'), {
      status: 'complete',
      updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(doc(db, 'projects/p1/tasks/t2'), {
      assigneeId: null,
      updatedAt: serverTimestamp(),
    }));
  });

  test("a task can't be reassigned to someone outside the project", async () => {
    await assertFails(updateDoc(doc(as('bob'), 'projects/p1/tasks/t1'), {
      assigneeId: 'dave',
      updatedAt: serverTimestamp(),
    }));
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
    await assertFails(updateDoc(doc(db, 'projects/p1/tasks/t1'), {
      checklist: [{ text: 'Step', done: true }],
      updatedAt: serverTimestamp(),
    }));
    // Completing records when, and reopening clears it.
    await assertSucceeds(updateDoc(doc(db, 'projects/p1/tasks/t1'), {
      status: 'complete',
      completedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(db, 'projects/p1/tasks/t1'), {
      status: 'inProgress',
      updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(doc(db, 'projects/p1/tasks/t1'), {
      status: 'inProgress',
      completedAt: null,
      updatedAt: serverTimestamp(),
    }));
  });

  test('editors can delete tasks, viewers cannot', async () => {
    await assertFails(deleteDoc(doc(as('carol'), 'projects/p1/tasks/t1')));
    await assertSucceeds(deleteDoc(doc(as('bob'), 'projects/p1/tasks/t1')));
  });
});

describe('comments and activity', () => {
  beforeEach(() => seed(async (db) => {
    await setDoc(doc(db, `${activityPath}/carols`), entry());
    await setDoc(doc(db, `${activityPath}/bobs`), entry({ authorId: 'bob', authorName: 'Bob' }));
    await setDoc(doc(db, `${activityPath}/moved`), entry({ kind: 'status', value: 'inProgress' }));
  }));

  test('members can read them, others cannot', async () => {
    const latest = (db) => query(collection(db, activityPath), orderBy('createdAt'));
    await assertSucceeds(getDocs(latest(as('carol'))));
    await assertFails(getDocs(latest(as('dave'))));
    await assertFails(getDocs(latest(signedOut())));
  });

  test('every member can comment, viewers included, but not outsiders', async () => {
    await assertSucceeds(setDoc(doc(as('carol'), `${activityPath}/new1`), entry()));
    await assertSucceeds(setDoc(doc(as('bob'), `${activityPath}/new2`), entry({ authorId: 'bob' })));
    await assertFails(setDoc(doc(as('dave'), `${activityPath}/new3`), entry({ authorId: 'dave' })));
  });

  test('an entry is in your own name, stamped by the server, and well formed', async () => {
    const add = (overrides) => setDoc(doc(as('carol'), `${activityPath}/new`), entry(overrides));
    await assertFails(add({ authorId: 'alice' }));
    await assertFails(add({ createdAt: Timestamp.fromMillis(0) }));
    await assertFails(add({ value: '' }));
    await assertFails(add({ value: 'x'.repeat(2001) }));
    await assertFails(add({ authorName: 'x'.repeat(101) }));
    await assertFails(add({ kind: 'reaction' }));
    await assertFails(add({ pinned: true }));
    await assertSucceeds(add({ value: 'x'.repeat(2000) }));
  });

  test('a viewer can log a status change and nothing else; an editor any change', async () => {
    const carol = as('carol');
    await assertSucceeds(setDoc(doc(carol, `${activityPath}/a`), entry({ kind: 'status', value: 'complete' })));
    await assertFails(setDoc(doc(carol, `${activityPath}/b`), entry({ kind: 'title', value: 'Renamed' })));
    await assertFails(setDoc(doc(carol, `${activityPath}/c`), entry({ kind: 'created', value: '' })));
    await assertSucceeds(setDoc(doc(as('bob'), `${activityPath}/d`), entry({ kind: 'title', authorId: 'bob', value: 'Renamed' })));
  });

  test("the app's writes: a change and its entry in one batch", async () => {
    // An editor creating a task.
    const bob = as('bob');
    const created = writeBatch(bob);
    created.set(doc(bob, 'projects/p1/tasks/t9'), task({ ownerId: 'bob' }));
    created.set(doc(bob, 'projects/p1/tasks/t9/activity/e1'), entry({ kind: 'created', authorId: 'bob', value: '' }));
    await assertSucceeds(created.commit());

    // A viewer ticking off the task assigned to them.
    const carol = as('carol');
    const done = writeBatch(carol);
    done.update(doc(carol, 'projects/p1/tasks/t1'), {
      status: 'complete',
      completedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    done.set(doc(carol, `${activityPath}/e2`), entry({ kind: 'status', value: 'complete' }));
    await assertSucceeds(done.commit());
  });

  test('no entries under a task that does not exist', async () => {
    await assertFails(setDoc(doc(as('bob'), 'projects/p1/tasks/nope/activity/e1'), entry({ authorId: 'bob' })));
  });

  test('entries are never edited, even by their author or the owner', async () => {
    await assertFails(updateDoc(doc(as('carol'), `${activityPath}/carols`), { value: 'Changed my mind' }));
    await assertFails(updateDoc(doc(as('alice'), `${activityPath}/carols`), { value: 'Rewritten' }));
  });

  test("a viewer can delete their own comment, but not other people's or the log", async () => {
    const carol = as('carol');
    await assertFails(deleteDoc(doc(carol, `${activityPath}/bobs`)));
    await assertFails(deleteDoc(doc(carol, `${activityPath}/moved`)));
    await assertSucceeds(deleteDoc(doc(carol, `${activityPath}/carols`)));
    await assertFails(deleteDoc(doc(as('dave'), `${activityPath}/bobs`)));
  });

  test("editors can delete anyone's comment, and a task together with its entries", async () => {
    const bob = as('bob');
    await assertSucceeds(deleteDoc(doc(bob, `${activityPath}/carols`)));

    const batch = writeBatch(bob);
    batch.delete(doc(bob, `${activityPath}/bobs`));
    batch.delete(doc(bob, `${activityPath}/moved`));
    batch.delete(doc(bob, 'projects/p1/tasks/t1'));
    await assertSucceeds(batch.commit());
  });

  test('personal tasks have none', async () => {
    const dave = as('dave');
    await assertFails(setDoc(doc(dave, 'tasks/personal1/activity/e1'), entry({ authorId: 'dave' })));
    await assertFails(getDocs(collection(dave, 'tasks/personal1/activity')));
  });
});

describe('recurring tasks', () => {
  const due = Timestamp.fromDate(new Date(Date.UTC(2026, 9, 5)));
  const nextDue = Timestamp.fromDate(new Date(Date.UTC(2026, 9, 12)));

  // t1 repeats weekly and is assigned to carol, a viewer.
  beforeEach(() => seed((db) => setDoc(doc(db, 'projects/p1/tasks/t1'), task({
    assigneeId: 'carol',
    dueDate: due,
    repeat: 'weekly',
    checklist: [{ text: 'Draft', done: true }],
  }))));

  const next = (overrides = {}) => task({
    ownerId: 'carol',
    assigneeId: 'carol',
    dueDate: nextDue,
    repeat: 'weekly',
    checklist: [{ text: 'Draft', done: false }],
    order: 1,
    repeatedFrom: 't1',
    ...overrides,
  });

  /** The app's batch when carol ticks off t1: the next task comes with it. */
  function completeAndContinue(db, { by = 'carol', from = 't1', nextTask = next(), stopRepeating = true } = {}) {
    const batch = writeBatch(db);
    batch.update(doc(db, `projects/p1/tasks/${from}`), {
      status: 'complete',
      completedAt: serverTimestamp(),
      ...(stopRepeating ? { repeat: null } : {}),
      updatedAt: serverTimestamp(),
    });
    batch.set(doc(db, `projects/p1/tasks/${from}/activity/e1`), entry({ kind: 'status', authorId: by, value: 'complete' }));
    batch.set(doc(db, 'projects/p1/tasks/t9'), nextTask);
    batch.set(doc(db, 'projects/p1/tasks/t9/activity/e2'), entry({ kind: 'created', authorId: by, value: '' }));
    return batch.commit();
  }

  test('a viewer who completes their repeating task adds the next one', async () => {
    await assertSucceeds(completeAndContinue(as('carol')));
  });

  test('only once: the schedule must come off the completed task', async () => {
    await assertFails(completeAndContinue(as('carol'), { stopRepeating: false }));
  });

  test("a viewer can't add a next task on its own", async () => {
    await assertFails(setDoc(doc(as('carol'), 'projects/p1/tasks/t9'), next()));
  });

  test('the next task must be a fresh copy, still theirs', async () => {
    const carol = as('carol');
    await assertFails(completeAndContinue(carol, { nextTask: next({ title: 'Something else' }) }));
    await assertFails(completeAndContinue(carol, { nextTask: next({ priority: 'immediate' }) }));
    await assertFails(completeAndContinue(carol, { nextTask: next({ repeat: 'daily' }) }));
    await assertFails(completeAndContinue(carol, { nextTask: next({ assigneeId: 'bob' }) }));
    await assertFails(completeAndContinue(carol, { nextTask: next({ status: 'complete' }) }));
    await assertFails(completeAndContinue(carol, { nextTask: next({ checklist: [] }) }));
  });

  test("not from a task that isn't theirs, or doesn't repeat", async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'projects/p1/tasks/bobs'), task({ assigneeId: 'bob', dueDate: due, repeat: 'weekly' }));
      await setDoc(doc(db, 'projects/p1/tasks/once'), task({ assigneeId: 'carol', dueDate: due }));
    });
    const carol = as('carol');
    await assertFails(completeAndContinue(carol, { from: 'bobs', nextTask: next({ repeatedFrom: 'bobs' }) }));
    await assertFails(completeAndContinue(carol, { from: 'once', nextTask: next({ repeatedFrom: 'once', repeat: null }) }));
  });

  test('a viewer can only take the schedule off as they complete the task', async () => {
    const t1 = doc(as('carol'), 'projects/p1/tasks/t1');
    await assertFails(updateDoc(t1, { repeat: null, updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(t1, { repeat: 'daily', updatedAt: serverTimestamp() }));
  });

  test('an editor can do the same, and change the schedule', async () => {
    const bob = as('bob');
    await assertSucceeds(updateDoc(doc(bob, 'projects/p1/tasks/t1'), {
      repeat: 'monthly',
      updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(completeAndContinue(bob, {
      by: 'bob',
      nextTask: next({ ownerId: 'bob', repeat: 'monthly' }),
    }));
  });

  test('a schedule must be one the app knows', async () => {
    const dave = as('dave');
    await assertSucceeds(setDoc(doc(dave, 'tasks/a'), task({ ownerId: 'dave', repeat: 'daily' })));
    await assertSucceeds(setDoc(doc(dave, 'tasks/b'), task({ ownerId: 'dave', repeat: 'weekly', repeatedFrom: 'a' })));
    await assertFails(setDoc(doc(dave, 'tasks/c'), task({ ownerId: 'dave', repeat: 'yearly' })));
    await assertFails(setDoc(doc(dave, 'tasks/d'), task({ ownerId: 'dave', repeatedFrom: 7 })));
  });
});

describe('labels', () => {
  const design = { name: 'Design', color: 'blue' };
  const labels = (n) => Array.from({ length: n }, (_, i) => ({ name: `Label ${i}`, color: 'red' }));

  test('a task has a list of at most 10 labels', async () => {
    const db = as('dave');
    await assertSucceeds(setDoc(doc(db, 'tasks/a'), task({ ownerId: 'dave', labels: labels(10) })));
    await assertFails(setDoc(doc(db, 'tasks/b'), task({ ownerId: 'dave', labels: labels(11) })));
    await assertFails(setDoc(doc(db, 'tasks/c'), task({ ownerId: 'dave', labels: 'Design' })));
    await assertSucceeds(updateDoc(doc(db, 'tasks/personal1'), {
      labels: [design],
      updatedAt: serverTimestamp(),
    }));
  });

  test("editors label project tasks; viewers can't, even their own", async () => {
    const change = (db) => updateDoc(doc(db, 'projects/p1/tasks/t1'), {
      labels: [design],
      updatedAt: serverTimestamp(),
    });
    await assertFails(change(as('carol')));
    await assertSucceeds(change(as('bob')));
  });

  test('editors can log a change of labels, viewers cannot', async () => {
    const log = (db, uid) => setDoc(
      doc(db, `projects/p1/tasks/t1/activity/${uid}`),
      entry({ kind: 'labels', authorId: uid, value: 'Design' }),
    );
    await assertFails(log(as('carol'), 'carol'));
    await assertSucceeds(log(as('bob'), 'bob'));
  });

  test("the next task in a series keeps the last one's labels", async () => {
    await seed((db) => setDoc(doc(db, 'projects/p1/tasks/t1'), task({
      assigneeId: 'carol',
      dueDate: Timestamp.fromDate(new Date(Date.UTC(2026, 9, 5))),
      repeat: 'weekly',
      labels: [design],
    })));
    const continueWith = (labels) => {
      const db = as('carol');
      const batch = writeBatch(db);
      batch.update(doc(db, 'projects/p1/tasks/t1'), {
        status: 'complete',
        completedAt: serverTimestamp(),
        repeat: null,
        updatedAt: serverTimestamp(),
      });
      batch.set(doc(db, 'projects/p1/tasks/t9'), task({
        ownerId: 'carol',
        assigneeId: 'carol',
        dueDate: Timestamp.fromDate(new Date(Date.UTC(2026, 9, 12))),
        repeat: 'weekly',
        repeatedFrom: 't1',
        labels,
      }));
      return batch.commit();
    };
    await assertFails(continueWith([{ name: 'Urgent', color: 'red' }]));
    await assertFails(continueWith([]));
    await assertSucceeds(continueWith([design]));
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

  test('a checklist must be a list of at most 50 items', async () => {
    const db = as('dave');
    const steps = (n) => Array.from({ length: n }, (_, i) => ({ text: `Step ${i}`, done: false }));
    await assertSucceeds(setDoc(doc(db, 'tasks/new'), task({ ownerId: 'dave', checklist: steps(50) })));
    await assertFails(setDoc(doc(db, 'tasks/new2'), task({ ownerId: 'dave', checklist: steps(51) })));
    await assertFails(setDoc(doc(db, 'tasks/new3'), task({ ownerId: 'dave', checklist: 'Step 1' })));
    // Older tasks have no checklist at all, and stay valid.
    await assertSucceeds(updateDoc(doc(db, 'tasks/personal1'), {
      title: 'Renamed',
      updatedAt: serverTimestamp(),
    }));
  });

  test('only a complete task has a completion time', async () => {
    const db = as('dave');
    const personal = doc(db, 'tasks/personal1');
    await assertFails(updateDoc(personal, {
      completedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(personal, {
      status: 'complete',
      completedAt: 'yesterday',
      updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(personal, {
      status: 'complete',
      completedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }));
    // Edited while done: the time stays.
    await assertSucceeds(updateDoc(personal, {
      title: 'Renamed',
      updatedAt: serverTimestamp(),
    }));
    // Reopened without clearing it.
    await assertFails(updateDoc(personal, {
      status: 'notStarted',
      updatedAt: serverTimestamp(),
    }));
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

  test('the invitee can list their pending invites by email', async () => {
    const db = as('erin');
    await assertSucceeds(getDocs(query(
      collection(db, 'invites'),
      where('email', '==', users.erin),
      where('status', '==', 'pending'),
    )));
    await assertFails(getDocs(query(
      collection(db, 'invites'),
      where('email', '==', users.alice),
    )));
  });

  test("the owner can list the invites they sent for a project", async () => {
    await assertSucceeds(getDocs(query(
      collection(as('alice'), 'invites'),
      where('projectId', '==', 'p1'),
      where('invitedBy', '==', 'alice'),
    )));
    // Without the invitedBy filter the query could return other people's.
    await assertFails(getDocs(query(
      collection(as('alice'), 'invites'),
      where('projectId', '==', 'p1'),
    )));
  });

  test('the invitee can decline, and change nothing else', async () => {
    const db = as('erin');
    await assertFails(updateDoc(doc(db, 'invites', erinInviteId), { role: 'editor' }));
    await assertSucceeds(updateDoc(doc(db, 'invites', erinInviteId), { status: 'declined' }));
  });

  test('the owner can cancel an invite', async () => {
    await assertFails(deleteDoc(doc(as('bob'), 'invites', erinInviteId)));
    await assertSucceeds(deleteDoc(doc(as('alice'), 'invites', erinInviteId)));
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

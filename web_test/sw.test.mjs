// Tests for web/sw.js, the service worker. Run with: node --test web_test/
//
// The worker is loaded into a small imitation of a browser: caches kept in
// maps, a "server" that is an object of files, and pages that collect the
// messages sent to them.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const source = readFileSync(new URL('../web/sw.js', import.meta.url), 'utf8');

const scope = 'https://taskly.test/app/';
const at = (path) => new URL(path, scope).href;

const version1 = {
  [at('./')]: '<html>one</html>',
  [at('flutter_bootstrap.js')]: 'bootstrap one',
  [at('main.dart.js')]: 'main one',
  [at('manifest.json')]: '{}',
  [at('assets/logo.png')]: 'logo one',
};
const version2 = {
  ...version1,
  [at('./')]: '<html>two</html>',
  [at('main.dart.js')]: 'main two',
  [at('assets/logo.png')]: 'logo two',
};

class FakeCache {
  entries = new Map();

  static key = (request) =>
    typeof request === 'string' ? request : request.url;

  async match(request) {
    return this.entries.get(FakeCache.key(request))?.clone();
  }

  async put(request, response) {
    this.entries.set(FakeCache.key(request), response);
  }
}

class FakeCaches {
  stores = new Map();

  async has(name) {
    return this.stores.has(name);
  }

  async open(name) {
    if (!this.stores.has(name)) this.stores.set(name, new FakeCache());
    return this.stores.get(name);
  }

  async delete(name) {
    return this.stores.delete(name);
  }

  /// What the cache called [name] holds, as text, or null without one.
  async read(name, url) {
    const response = await this.stores.get(name)?.match(url);
    return response === undefined ? null : response.text();
  }
}

/// Starts the worker with [files] on the server, and installs it.
async function start(files = version1) {
  const world = {
    files: { ...files },
    offline: false,
    requests: [],
    pages: [],
    caches: new FakeCaches(),
  };
  const listeners = {};
  const self = {
    registration: { scope },
    addEventListener: (type, listener) => (listeners[type] = listener),
    skipWaiting: async () => {},
    clients: { claim: async () => {}, matchAll: async () => world.pages },
  };
  const fetch = async (request) => {
    const url = typeof request === 'string' ? request : request.url;
    world.requests.push(url);
    if (world.offline) throw new TypeError('Failed to fetch');
    const body = world.files[url];
    return body === undefined
      ? new Response('not found', { status: 404 })
      : new Response(body);
  };
  new Function('self', 'caches', 'fetch', source)(self, world.caches, fetch);

  /// Sends the worker an event, and waits for everything it starts.
  const dispatch = async (type, properties = {}) => {
    const waits = [];
    let answer;
    listeners[type]({
      ...properties,
      waitUntil: (promise) => waits.push(promise),
      respondWith: (promise) => (answer = promise),
    });
    const response = await answer;
    await Promise.all(waits);
    return response;
  };

  /// A new tab, which collects the messages the worker sends it.
  world.openPage = () => {
    const page = { messages: [] };
    page.postMessage = (message) => page.messages.push(message);
    world.pages.push(page);
    return page;
  };
  /// What the worker answers to a request, as text. Null when it leaves the
  /// request to the browser.
  world.get = async (url, { mode = 'no-cors', method = 'GET' } = {}) => {
    const request = { url, method, mode, headers: new Headers() };
    const response = await dispatch('fetch', { request });
    return response === undefined ? null : response.text();
  };
  world.open = (path) => world.get(at(path), { mode: 'navigate' });
  world.send = (page, data) => dispatch('message', { data, source: page });

  await dispatch('install');
  await dispatch('activate');
  return world;
}

test('installing keeps a copy of the app', async () => {
  const world = await start();

  assert.equal(
    await world.caches.read('taskly-app', at('main.dart.js')),
    'main one',
  );
  assert.equal(await world.caches.read('taskly-app', at('./')), '<html>one</html>');
});

test('every page of the app is the same index.html, with or without a connection', async () => {
  const world = await start();
  world.offline = true;

  assert.equal(await world.open('./'), '<html>one</html>');
  assert.equal(await world.open('projects/abc'), '<html>one</html>');
  assert.equal(await world.get(at('main.dart.js')), 'main one');
});

test('other files are fetched once, then kept', async () => {
  const world = await start();

  assert.equal(await world.get(at('assets/logo.png')), 'logo one');
  world.offline = true;
  assert.equal(await world.get(at('assets/logo.png')), 'logo one');
});

test('a file the server does not have is not kept', async () => {
  const world = await start();

  assert.equal(await world.get(at('assets/missing.png')), 'not found');
  assert.equal(
    await world.caches.read('taskly-app', at('assets/missing.png')),
    null,
  );
});

test('requests that are not the app are left to the browser', async () => {
  const world = await start();

  const firestore = 'https://firestore.googleapis.com/google.firestore.v1/Listen';
  assert.equal(await world.get(firestore), null);
  assert.equal(await world.get(at('main.dart.js'), { method: 'POST' }), null);
  // Firebase Hosting's own pages, which signing in with Google goes through.
  assert.equal(await world.get(at('__/auth/handler'), { mode: 'navigate' }), null);
  // Outside the folder the app is served from.
  assert.equal(await world.get('https://taskly.test/other/'), null);
  assert.deepEqual(
    world.requests.filter((url) => !Object.hasOwn(version1, url)),
    [],
  );
});

test('a file opened in a tab is that file, not the app', async () => {
  const world = await start();

  assert.equal(await world.open('manifest.json'), '{}');
});

test('the engine and fonts from Google are kept too', async () => {
  const world = await start();
  const engine = 'https://www.gstatic.com/flutter-canvaskit/abc/canvaskit.wasm';
  world.files[engine] = 'engine';

  assert.equal(await world.get(engine, { mode: 'cors' }), 'engine');
  world.offline = true;
  assert.equal(await world.get(engine, { mode: 'cors' }), 'engine');
});

test('checking with nothing new says so, and downloads nothing', async () => {
  const world = await start();
  const page = world.openPage();

  await world.send(page, { type: 'check' });

  assert.deepEqual(page.messages, [{ type: 'update', ready: false }]);
  assert.equal(await world.caches.has('taskly-next'), false);
});

test('a new version is downloaded while pages keep the old one', async () => {
  const world = await start();
  const page = world.openPage();
  const other = world.openPage();
  world.files = { ...version2 };

  await world.send(page, { type: 'check' });

  // Every open tab hears about it.
  assert.deepEqual(page.messages, [{ type: 'update', ready: true }]);
  assert.deepEqual(other.messages, [{ type: 'update', ready: true }]);
  assert.equal(await world.get(at('main.dart.js')), 'main one');
  assert.equal(
    await world.caches.read('taskly-next', at('main.dart.js')),
    'main two',
  );
});

test('applying switches to the new version and reloads the page that asked', async () => {
  const world = await start();
  const page = world.openPage();
  const other = world.openPage();
  await world.get(at('assets/logo.png'));
  world.files = { ...version2 };
  await world.send(page, { type: 'check' });

  await world.send(page, { type: 'apply' });

  assert.deepEqual(page.messages.at(-1), { type: 'reload' });
  // Another tab may have something half-written in it.
  assert.equal(other.messages.some((message) => message.type === 'reload'), false);
  assert.equal(await world.open('./'), '<html>two</html>');
  assert.equal(await world.get(at('main.dart.js')), 'main two');
  // What the old version had collected went with it.
  assert.equal(await world.get(at('assets/logo.png')), 'logo two');
  assert.equal(await world.caches.has('taskly-next'), false);
});

test('applying with nothing waiting just reloads', async () => {
  const world = await start();
  const page = world.openPage();

  await world.send(page, { type: 'apply' });

  assert.deepEqual(page.messages, [{ type: 'reload' }]);
  assert.equal(await world.open('./'), '<html>one</html>');
});

test('opening the app switches to a waiting version by itself', async () => {
  const world = await start();
  const page = world.openPage();
  world.files = { ...version2 };
  await world.send(page, { type: 'check' });

  // The only tab is reloaded, or was closed and the app opened again.
  assert.equal(await world.open('./'), '<html>two</html>');
  assert.equal(await world.get(at('main.dart.js')), 'main two');
});

test('but not while another tab is still running the old one', async () => {
  const world = await start();
  const page = world.openPage();
  world.openPage();
  world.files = { ...version2 };
  await world.send(page, { type: 'check' });

  assert.equal(await world.open('./'), '<html>one</html>');
  assert.equal(await world.get(at('main.dart.js')), 'main one');
});

test('checking again does not download the same new version twice', async () => {
  const world = await start();
  const page = world.openPage();
  world.files = { ...version2 };
  await world.send(page, { type: 'check' });
  const next = world.caches.stores.get('taskly-next');

  await world.send(page, { type: 'check' });

  assert.equal(world.caches.stores.get('taskly-next'), next);
  assert.deepEqual(page.messages.at(-1), { type: 'update', ready: true });
});

test('a newer version still replaces one that is waiting', async () => {
  const world = await start();
  const page = world.openPage();
  world.files = { ...version2 };
  await world.send(page, { type: 'check' });
  world.files = { ...version2, [at('main.dart.js')]: 'main three' };

  await world.send(page, { type: 'check' });
  await world.send(page, { type: 'apply' });

  assert.equal(await world.get(at('main.dart.js')), 'main three');
});

test('checking without a connection changes nothing', async () => {
  const world = await start();
  const page = world.openPage();
  world.offline = true;

  await world.send(page, { type: 'check' });

  assert.deepEqual(page.messages, [{ type: 'update', ready: false }]);
  assert.equal(await world.open('./'), '<html>one</html>');
});

test('a server in the middle of a deploy is not taken for a new version', async () => {
  const world = await start();
  const page = world.openPage();
  world.files = { ...version2 };
  delete world.files[at('main.dart.js')];

  await world.send(page, { type: 'check' });

  assert.deepEqual(page.messages, [{ type: 'update', ready: false }]);
  assert.equal(await world.caches.has('taskly-next'), false);
});

test('a copy the browser threw away is fetched again without asking', async () => {
  const world = await start();
  const page = world.openPage();
  await world.caches.delete('taskly-app');
  world.files = { ...version2 };

  // Until then the page comes from the network.
  assert.equal(await world.open('./'), '<html>two</html>');
  await world.send(page, { type: 'check' });

  assert.deepEqual(page.messages, [{ type: 'update', ready: false }]);
  assert.equal(await world.caches.read('taskly-app', at('main.dart.js')), 'main two');
});

test('"keep" adds what the first page loaded before the worker was there', async () => {
  const world = await start();
  const page = world.openPage();
  const font = 'https://fonts.gstatic.com/s/montserrat/v1/font.woff2';
  const firestore = 'https://firestore.googleapis.com/channel';
  world.files[font] = 'font';
  world.files[firestore] = 'data';

  await world.send(page, {
    type: 'keep',
    urls: [at('assets/logo.png'), font, firestore, at('sw.js'), 'not a url'],
  });

  assert.equal(await world.caches.read('taskly-app', at('assets/logo.png')), 'logo one');
  assert.equal(await world.caches.read('taskly-libraries', font), 'font');
  assert.equal(world.requests.includes(firestore), false);
  assert.equal(world.requests.includes(at('sw.js')), false);
});

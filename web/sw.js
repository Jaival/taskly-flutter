'use strict';

// Taskly's service worker. Flutter doesn't generate one any more, so this one
// is written by hand. It does two things:
//
// 1. Keeps a copy of the app on the device, so it opens at once and without
//    a connection. A running page is only ever served from that copy, so the
//    files it gets always belong together.
// 2. Notices a newer version. When a page asks ("check"), the core files are
//    compared with the server's, byte for byte. A different set is downloaded
//    into a second cache and the pages are told. It replaces the first when
//    the user chooses to reload ("apply"), or the next time the app is opened.
//
// Nothing here needs a version number from the build.
// See devops.md 9, "Installing the app, and updating it".

const APP = 'taskly-app'; // the version in use
const NEXT = 'taskly-next'; // a newer one, downloaded and waiting
const LIBRARIES = 'taskly-libraries'; // Flutter's engine, Firebase and fonts

// The files that make up a version. The rest are added as pages ask for them.
const CORE = ['./', 'flutter_bootstrap.js', 'main.dart.js', 'manifest.json'];

const scope = self.registration.scope;
const coreUrls = CORE.map((path) => new URL(path, scope).href);
const pageUrl = coreUrls[0];

// Google serves these under addresses that never change their content.
const isLibrary = (url) =>
  url.origin === 'https://www.gstatic.com' ||
  url.origin === 'https://fonts.gstatic.com';

// The app's own files. Not Firebase Hosting's reserved paths (signing in
// with Google goes through them), and not this file.
const isApp = (url) =>
  url.href.startsWith(scope) &&
  !url.href.startsWith(`${scope}__/`) &&
  url.href !== new URL('sw.js', scope).href;

// A page of the app rather than one of its files: /projects/abc, not
// /manifest.json. Every page is the same index.html.
const isPage = (request, url) =>
  request.mode === 'navigate' && !url.pathname.split('/').pop().includes('.');

/// Whether the cache called [name] holds a whole version.
async function holds(name) {
  if (!(await caches.has(name))) return false;
  const cache = await caches.open(name);
  const found = await Promise.all(coreUrls.map((url) => cache.match(url)));
  return found.every(Boolean);
}

/// Fetches the core files, all or nothing. [mode] 'no-cache' asks the server
/// whether the browser's own copy is still current.
function download(mode) {
  return Promise.all(
    coreUrls.map(async (url) => {
      const response = await fetch(url, { cache: mode });
      if (!response.ok) throw new Error(`${response.status} for ${url}`);
      // A response that followed a redirect can't answer a navigation.
      if (!response.redirected) return [url, response];
      const { status, statusText, headers } = response;
      return [url, new Response(response.body, { status, statusText, headers })];
    }),
  );
}

async function store(name, files) {
  const cache = await caches.open(name);
  await Promise.all(files.map(([url, response]) => cache.put(url, response)));
}

async function sameBytes(a, b) {
  const [x, y] = (await Promise.all([a.arrayBuffer(), b.arrayBuffer()])).map(
    (buffer) => new Uint8Array(buffer),
  );
  return x.length === y.length && x.every((byte, i) => byte === y[i]);
}

/// Looks for a newer version on the server and downloads it into [NEXT].
/// Returns whether one is waiting there.
async function findUpdate() {
  try {
    if (!(await holds(APP))) {
      // The browser threw the copy away. Whatever the server has is current.
      await caches.delete(APP);
      await store(APP, await download('no-cache'));
    } else {
      const newest = await caches.open((await holds(NEXT)) ? NEXT : APP);
      const files = await download('no-cache');
      const same = await Promise.all(
        files.map(async ([url, response]) =>
          sameBytes(await newest.match(url), response.clone()),
        ),
      );
      if (!same.every(Boolean)) {
        await caches.delete(NEXT);
        await store(NEXT, files);
      }
    }
  } catch (error) {
    // Offline, or the server is in the middle of a deploy. Ask again later.
  }
  return holds(NEXT);
}

// One check at a time, however many pages ask.
let checking = null;
function check() {
  checking ??= findUpdate().finally(() => {
    checking = null;
  });
  return checking;
}

/// Makes the waiting version the one in use. The files the old one had
/// collected go with it.
async function promote() {
  if (!(await holds(NEXT))) return;
  const next = await caches.open(NEXT);
  await caches.delete(APP);
  const app = await caches.open(APP);
  await Promise.all(
    coreUrls.map(async (url) => app.put(url, await next.match(url))),
  );
  await caches.delete(NEXT);
}

async function announce(ready) {
  const pages = await self.clients.matchAll({ type: 'window' });
  for (const page of pages) page.postMessage({ type: 'update', ready });
}

/// Answers from the cache, and from the network the first time.
async function kept(event, name) {
  const cache = await caches.open(name);
  const hit = await cache.match(event.request, { ignoreVary: true });
  if (hit) return hit;
  const response = await fetch(event.request);
  if (response.ok) {
    event.waitUntil(cache.put(event.request, response.clone()).catch(() => {}));
  }
  return response;
}

async function page(event) {
  if (await holds(NEXT)) {
    // The app is being opened or reloaded. If no other tab still runs the
    // old version, this is the moment to switch.
    const open = await self.clients.matchAll({ type: 'window' });
    if (open.length <= 1) await promote();
  }
  const app = await caches.open(APP);
  return (await app.match(pageUrl)) ?? fetch(event.request);
}

/// Adds what a page loaded before this worker was in charge of it: without
/// these, the first visit wouldn't be enough to open the app offline.
async function keep(urls) {
  for (const href of urls) {
    try {
      const url = new URL(href);
      const name = isLibrary(url) ? LIBRARIES : isApp(url) ? APP : null;
      if (name === null) continue;
      const cache = await caches.open(name);
      if (await cache.match(href, { ignoreVary: true })) continue;
      const response = await fetch(href);
      if (response.ok) await cache.put(href, response);
    } catch (error) {
      // One file less in the cache; it's fetched when it's next needed.
    }
  }
}

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      if (!(await holds(APP))) {
        await caches.delete(APP);
        await store(APP, await download('default'));
      }
      // A new version of this file takes over at once: the caches, and so
      // the app the pages are running, stay as they are.
      await self.skipWaiting();
    })(),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET' || request.headers.has('range')) return;
  const url = new URL(request.url);
  if (isLibrary(url)) {
    event.respondWith(kept(event, LIBRARIES));
  } else if (!isApp(url)) {
    // Firebase and everything else: straight to the network.
  } else if (isPage(request, url)) {
    event.respondWith(page(event));
  } else {
    event.respondWith(kept(event, APP));
  }
});

self.addEventListener('message', (event) => {
  const { type, urls } = event.data ?? {};
  if (type === 'check') {
    event.waitUntil(check().then(announce));
  } else if (type === 'apply') {
    event.waitUntil(
      promote().then(() => event.source.postMessage({ type: 'reload' })),
    );
  } else if (type === 'keep') {
    event.waitUntil(keep(urls ?? []));
  }
});

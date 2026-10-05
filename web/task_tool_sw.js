// SPDX-License-Identifier: AGPL-3.0-or-later
// Opt-in, verified offline snapshot. Online responses never partly overwrite
// it. Only build-manifest assets are eligible; no API response is cached.
const SCOPE = encodeURIComponent(self.registration.scope);
const META = 'deskilo-task-tool-state-' + SCOPE;
const PREFIX = 'deskilo-task-tool-v2-' + SCOPE + '-';
const MANIFEST = new URL('task_tool_manifest.json', self.registration.scope).href;
const STATE = new URL('task-tool-ready', self.registration.scope).href;
let busy = Promise.resolve();

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

async function snapshot() {
  const response = await (await caches.open(META)).match(STATE);
  return response ? response.json() : null;
}

async function ready() {
  const saved = await snapshot();
  if (!saved) return false;
  const cache = await caches.open(PREFIX + saved.version);
  for (const file of saved.files) {
    if (!await cache.match(file.url)) return false;
  }
  return true;
}

async function keep() {
  const response = await fetch(MANIFEST, {cache: 'no-store'});
  if (!response.ok) throw new Error('manifest unavailable');
  const manifest = await response.json();
  if (!/^[a-f0-9]{64}$/.test(manifest.version) || !manifest.files?.length) {
    throw new Error('invalid manifest');
  }
  const files = manifest.files.map((file) => {
    const url = new URL(file.path, self.registration.scope);
    if (!url.href.startsWith(self.registration.scope) ||
        url.search || url.hash || !/^[a-f0-9]{64}$/.test(file.sha256)) {
      throw new Error('invalid asset');
    }
    return {...file, url: url.href};
  });
  const previous = await snapshot();
  const cache = await caches.open(PREFIX + manifest.version);
  try {
  for (const file of files) {
    const asset = await fetch(file.url, {cache: 'no-store'});
    if (!asset.ok) throw new Error('asset unavailable');
    const bytes = await asset.clone().arrayBuffer();
    const digest = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes)))
      .map((byte) => byte.toString(16).padStart(2, '0')).join('');
    if (digest !== file.sha256) throw new Error('asset changed during installation');
    await cache.put(file.url, asset);
  }
  } catch (error) {
    if (previous?.version !== manifest.version) await caches.delete(PREFIX + manifest.version);
    throw error;
  }
  // Commit only after every required asset has been downloaded and verified.
  await (await caches.open(META)).put(STATE,
    new Response(JSON.stringify({version: manifest.version, files})));
  for (const name of await caches.keys()) {
    if ((name.startsWith(PREFIX) && name !== PREFIX + manifest.version) ||
        name === 'deskilo-task-tool-v1') await caches.delete(name);
  }
  return ready();
}

async function forget() {
  for (const name of await caches.keys()) {
    if (name === META || name.startsWith(PREFIX) || name === 'deskilo-task-tool-v1') {
      await caches.delete(name);
    }
  }
  return true;
}

self.addEventListener('message', (event) => {
  const operation = async () => {
    try {
      const ok = await (event.data === 'keep' ? keep() :
        event.data === 'forget' ? forget() : ready());
      event.ports[0]?.postMessage(ok);
    } catch (error) {
      console.warn('Offline task copy failed', error.name);
      event.ports[0]?.postMessage(false);
    }
  };
  // A forget cannot race an installation and leave a hidden retained copy.
  busy = busy.then(operation, operation);
  event.waitUntil(busy);
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (!url.href.startsWith(self.registration.scope)) return;
  event.respondWith((async () => {
    try {
      return await fetch(request);
    } catch (error) {
      const saved = await snapshot();
      if (!saved) throw error;
      const cache = await caches.open(PREFIX + saved.version);
      const key = request.mode === 'navigate'
        ? new URL('index.html', self.registration.scope).href : request.url;
      if (!saved.files.some((file) => file.url === key)) throw error;
      const hit = await cache.match(key);
      if (!hit) throw error;
      return hit;
    }
  })());
});

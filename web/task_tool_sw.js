// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1886 — keeps the task workbench usable without a connection, on this
// browser, after the person asked for it ("Keep it on this device").
//
// Network first: online, every file comes fresh from the server exactly
// as without this worker, and a copy is kept; offline, the kept copy is
// served. Only GET requests for this app's own files and the static
// font/engine hosts are touched — never a backend call, never a write,
// never a recording (recordings never leave the page). Unregistering it
// from the workbench removes it and its cache.

const CACHE = 'deskilo-task-tool-v1';
const STATIC_HOSTS = ['www.gstatic.com', 'fonts.gstatic.com', 'fonts.googleapis.com'];

self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('message', (event) => {
  if (event.data === 'forget') {
    event.waitUntil(caches.delete(CACHE));
  }
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  const own = url.origin === self.location.origin;
  if (!own && !STATIC_HOSTS.includes(url.host)) return;
  event.respondWith(
    fetch(request)
      .then((response) => {
        if (response.ok || response.type === 'opaque') {
          const copy = response.clone();
          caches.open(CACHE).then((cache) => cache.put(request, copy));
        }
        return response;
      })
      .catch(() =>
        caches.match(request).then(
          (hit) => hit || (request.mode === 'navigate' ? caches.match('./') : undefined),
        ),
      ),
  );
});

// SPDX-License-Identifier: AGPL-3.0-or-later
// Actual service-worker/browser storage: first install -> offline reopening,
// failed update, evicted asset, backend exclusion and explicit removal.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {chromium} from 'playwright';

const worker = await readFile(new URL('../../web/task_tool_sw.js', import.meta.url));
const assets = new Map([
  ['index.html', '<html><body>Offline task fixture<script src="runtime.js"></script></body></html>'],
  ['runtime.js', 'window.taskRuntimeReady = true;'],
]);
const hash = (data) => createHash('sha256').update(data).digest('hex');
const manifest = () => {
  const files = [...assets].map(([path, data]) => ({path, sha256: hash(data)}));
  return {version: hash(JSON.stringify(files)), files};
};
let corrupt = false;
const server = createServer((req, res) => {
  const name = req.url.replace(/^\/nested\//, '');
  res.setHeader('Content-Type', name.endsWith('.js') ? 'text/javascript' :
    name.endsWith('.json') ? 'application/json' : 'text/html');
  if (name === 'task_tool_sw.js') return res.end(worker);
  if (name === 'task_tool_manifest.json') return res.end(JSON.stringify(manifest()));
  if (name === 'api/private') return res.end('PRIVATE-CANARY');
  if (assets.has(name)) return res.end(corrupt && name === 'runtime.js' ? 'wrong build' : assets.get(name));
  res.writeHead(404).end();
});
await new Promise((ok) => server.listen(0, '127.0.0.1', ok));
const base = `http://127.0.0.1:${server.address().port}/nested/`;
let browser;
try {
  browser = await chromium.launch(process.env.BROWSER_EXECUTABLE ?
    {executablePath: process.env.BROWSER_EXECUTABLE} : {});
  const context = await browser.newContext();
  let page = await context.newPage();
  await page.goto(base + 'index.html');
  await page.evaluate(async () => {
    await navigator.serviceWorker.register('task_tool_sw.js');
    await navigator.serviceWorker.ready;
  });
  const command = (value) => page.evaluate(async (value) => {
    const r = await navigator.serviceWorker.ready;
    return new Promise((resolve, reject) => {
      const c = new MessageChannel();
      const timeout = setTimeout(() => reject(Error('worker timeout')), 10000);
      c.port1.onmessage = (event) => { clearTimeout(timeout); c.port1.close(); resolve(event.data); };
      r.active.postMessage(value, [c.port2]);
    });
  }, value);
  assert.equal(await command('state'), false, 'registration alone is not ready');
  assert.equal(await command('keep'), true);
  await page.evaluate(() => fetch('api/private'));
  await context.setOffline(true);
  await page.close();
  page = await context.newPage();
  await page.goto(base + 'task-workbench'); // cold deep-link shell fallback
  assert.equal(await page.evaluate(() => window.taskRuntimeReady), true);
  assert.equal(await command('state'), true);
  assert.equal(await page.evaluate(async () => {
    try { await fetch('api/private'); return false; } catch { return true; }
  }), true, 'private API response must never be an offline asset');
  await context.setOffline(false);
  assets.set('runtime.js', 'window.taskRuntimeReady = "new";');
  corrupt = true;
  assert.equal(await command('keep'), false, 'mixed build is refused');
  assert.equal(await command('state'), true, 'last complete version survives');
  assert.equal((await page.evaluate(() => caches.keys())).length, 2, 'failed installation leaves no partial cache');
  await context.setOffline(true);
  await page.reload();
  assert.equal(await page.evaluate(() => window.taskRuntimeReady), true);
  await page.evaluate(async () => {
    for (const name of await caches.keys()) {
      if (name.startsWith('deskilo-task-tool-v2-')) {
        await (await caches.open(name)).delete(new URL('runtime.js', location.href).href);
      }
    }
  });
  assert.equal(await command('state'), false, 'evicted asset revokes readiness');
  assert.equal(await command('forget'), true);
  assert.deepEqual(await page.evaluate(() => caches.keys()), []);
  console.log('PASS: fresh offline reopen, integrity failure, eviction, privacy, removal');
} finally {
  await browser?.close();
  await new Promise((ok) => server.close(ok));
}

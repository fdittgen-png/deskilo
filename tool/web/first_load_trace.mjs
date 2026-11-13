// SPDX-License-Identifier: AGPL-3.0-or-later
// #3622 -- a request trace of the web build's first load, not a sum of the
// build folder. Serves build/web the way a static host does (gzip for text,
// SPA fallback), opens it in a cold browser context (no cache, no service
// worker) and records every response until two moments:
//   first_frame -- Flutter has put its view in the page (flt-glass-pane);
//   settled     -- no request for 3 s after that (what a visitor has fetched
//                  once the app sits idle on its first screen).
// Bytes are the size on the wire: gzip level 6 for compressible types, the
// raw file for images, as GitHub Pages sends them.
//
//   node tool/web/first_load_trace.mjs [--dir build/web] [--json out.json]
//   BROWSER_EXECUTABLE=<path> picks a browser the runner already has.
import {createServer} from 'node:http';
import {readFile, stat, writeFile} from 'node:fs/promises';
import {gzipSync} from 'node:zlib';
import {extname, join, normalize, resolve} from 'node:path';
import {chromium} from 'playwright';

const args = process.argv.slice(2);
const opt = (name, fallback) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : fallback;
};
const dir = resolve(opt('--dir', 'build/web'));
const jsonOut = opt('--json', null);
const types = {
  '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json',
  '.wasm': 'application/wasm', '.png': 'image/png', '.ico': 'image/x-icon',
  '.otf': 'font/otf', '.ttf': 'font/ttf', '.txt': 'text/plain', '.md': 'text/markdown',
  '.css': 'text/css', '.svg': 'image/svg+xml', '.bin': 'application/octet-stream',
};
const compressible = new Set(['.html', '.js', '.json', '.wasm', '.txt', '.md', '.css', '.svg', '.otf', '.ttf', '.bin']);
// The build may be made for a sub-path (--base-href /repo/); serve it there.
const prefix = /<base href="([^"]*)"/.exec(await readFile(join(dir, 'index.html'), 'utf8'))?.[1] ?? '/';
const strip = (p) => (p.startsWith(prefix) ? '/' + p.slice(prefix.length) : p);
const wire = new Map(); // url path -> bytes on the wire

const server = createServer(async (req, res) => {
  const raw = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  const path = strip(raw);
  let file = join(dir, normalize(path));
  try {
    if (!file.startsWith(dir) || !(await stat(file)).isFile()) throw new Error('no');
  } catch {
    file = join(dir, 'index.html'); // the SPA fallback of the static host
  }
  const body = await readFile(file);
  const ext = extname(file);
  const out = compressible.has(ext) ? gzipSync(body, {level: 6}) : body;
  wire.set(raw, out.length);
  res.writeHead(200, {
    'Content-Type': types[ext] ?? 'application/octet-stream',
    ...(out !== body ? {'Content-Encoding': 'gzip'} : {}),
  });
  res.end(out);
});
await new Promise((ok) => server.listen(0, '127.0.0.1', ok));
const base = `http://127.0.0.1:${server.address().port}${prefix}`;

const browser = await chromium.launch(process.env.BROWSER_EXECUTABLE ?
  {executablePath: process.env.BROWSER_EXECUTABLE} : {});
const context = await browser.newContext({serviceWorkers: 'block', viewport: {width: 1440, height: 900}});
const page = await context.newPage();
const log = []; // {path, bytes, atMs}
const t0 = Date.now();
page.on('requestfinished', (request) => {
  const url = new URL(request.url());
  if (url.origin !== new URL(base).origin) return;
  log.push({path: strip(url.pathname), bytes: wire.get(url.pathname) ?? 0, atMs: Date.now() - t0});
});
await page.goto(base, {waitUntil: 'commit'});
await page.waitForSelector('flt-glass-pane', {state: 'attached', timeout: 120000});
const firstFrameAt = Date.now() - t0;
let last = log.length;
for (let quiet = 0; quiet < 3000;) { // settle: 3 s without a new request
  await page.waitForTimeout(250);
  quiet = log.length === last ? quiet + 250 : 0;
  last = log.length;
}
await browser.close();
server.close();

const sum = (rows) => rows.reduce((a, r) => a + r.bytes, 0);
const before = log.filter((r) => r.atMs <= firstFrameAt);
const group = (rows) => {
  const g = {};
  for (const r of rows) {
    const key = r.path.startsWith('/assets/assets/help/images/') ? 'help_images'
      : r.path.startsWith('/assets/assets/help/') ? 'help_text'
      : r.path.startsWith('/assets/assets/instance/') ? 'instance_bundle'
      : r.path.startsWith('/assets/') ? 'other_assets'
      : r.path.startsWith('/canvaskit/') ? 'engine'
      : r.path.endsWith('.js') ? 'scripts' : 'other';
    g[key] = (g[key] ?? 0) + r.bytes;
  }
  return g;
};
const result = {
  first_frame_ms: firstFrameAt,
  first_frame_bytes: sum(before),
  settled_bytes: sum(log),
  settled_requests: log.length,
  first_frame_by_group: group(before),
  settled_by_group: group(log),
  requests: log,
};
console.log(JSON.stringify({...result, requests: undefined}, null, 2));
if (jsonOut) await writeFile(jsonOut, JSON.stringify(result, null, 2) + '\n');

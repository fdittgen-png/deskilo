// SPDX-License-Identifier: AGPL-3.0-or-later
// Serves public/ — the DesKilo welcome page, user guide, setup guide and setup
// questionnaire. Plain Node, no dependencies, so `npm install` has nothing to fetch.
'use strict';
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');

const ROOT = path.join(__dirname, 'public');
const HOME = '/welcome/';
const TYPES = {
  '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8', '.txt': 'text/plain; charset=utf-8', '.svg': 'image/svg+xml',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp', '.ico': 'image/x-icon',
  '.woff2': 'font/woff2', '.map': 'application/json',
};
const COMPRESSIBLE = new Set(['.html', '.css', '.js', '.json', '.txt', '.svg']);
// Screenshots carry a build stamp in their name (…b8fa17aa9.jpg): a new build is a new URL.
const STAMPED = /\.b[0-9a-f]{6,}\.(jpg|webp|png)$/;
const gzipCache = new Map();

function resolveFile(urlPath) {
  let rel;
  try { rel = decodeURIComponent(urlPath); } catch { return null; }
  if (rel.includes('\0')) return null;
  const full = path.normalize(path.join(ROOT, rel));
  if (full !== ROOT && !full.startsWith(ROOT + path.sep)) return null; // path traversal
  return full;
}

function send(req, res, status, headers, body) {
  res.writeHead(status, {
    'X-Content-Type-Options': 'nosniff', 'Referrer-Policy': 'strict-origin-when-cross-origin',
    'X-Frame-Options': 'SAMEORIGIN', ...headers,
  });
  res.end(req.method === 'HEAD' ? undefined : body);
}

const server = http.createServer((req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') return send(req, res, 405, { Allow: 'GET, HEAD' }, 'Method not allowed');
  const url = new URL(req.url, 'http://localhost');
  if (url.pathname === '/healthz') return send(req, res, 200, { 'Content-Type': 'text/plain' }, 'ok');
  if (url.pathname === '/') return send(req, res, 302, { Location: HOME + url.search }, '');

  let file = resolveFile(url.pathname);
  if (!file) return send(req, res, 400, { 'Content-Type': 'text/plain' }, 'Bad request');
  let stat = fs.statSync(file, { throwIfNoEntry: false });
  if (stat?.isDirectory()) {
    if (!url.pathname.endsWith('/')) return send(req, res, 301, { Location: url.pathname + '/' + url.search }, '');
    file = path.join(file, 'index.html');
    stat = fs.statSync(file, { throwIfNoEntry: false });
  }
  if (!stat?.isFile()) {
    const notFound = path.join(ROOT, '404.html');
    const page = fs.existsSync(notFound) ? fs.readFileSync(notFound) : 'Not found';
    return send(req, res, 404, { 'Content-Type': 'text/html; charset=utf-8' }, page);
  }

  const ext = path.extname(file).toLowerCase();
  const etag = `W/"${stat.size.toString(16)}-${Math.floor(stat.mtimeMs).toString(16)}"`;
  const headers = {
    'Content-Type': TYPES[ext] || 'application/octet-stream', ETag: etag, Vary: 'Accept-Encoding',
    'Cache-Control': STAMPED.test(file) ? 'public, max-age=31536000, immutable' : ext === '.html' ? 'no-cache' : 'public, max-age=3600',
  };
  if (req.headers['if-none-match'] === etag) return send(req, res, 304, headers, '');

  let body = fs.readFileSync(file);
  if (COMPRESSIBLE.has(ext) && /\bgzip\b/.test(req.headers['accept-encoding'] || '')) {
    const hit = gzipCache.get(file);
    const zipped = hit?.etag === etag ? hit.body : zlib.gzipSync(body);
    gzipCache.set(file, { etag, body: zipped });
    body = zipped;
    headers['Content-Encoding'] = 'gzip';
  }
  headers['Content-Length'] = body.length;
  send(req, res, 200, headers, body);
});

// Passenger (cPanel / GoDaddy) hands the port over in PORT or intercepts listen().
server.listen(process.env.PORT || 3000, () => console.log(`DesKilo site on ${server.address().port}`));

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1629 — the self-hosted API reference keeps its contract without a
// browser: pinned, checksummed Swagger UI; no inline or foreign script;
// no external validator, no ?url= injection, no persisted authorization,
// PKCE; and the document it serves is the generated one.
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import { SWAGGER_OPTIONS, OAUTH_OPTIONS } from '../../web/api/init.js';

const dir = new URL('../../web/api/', import.meta.url);
const read = (f) => fs.readFileSync(new URL(f, dir));
let cases = 0;
const t = (name, fn) => { fn(); cases++; };

t('the vendored files are the pinned, checksummed release', () => {
  const lines = read('VENDORED.txt').toString().trim().split('\n');
  assert.match(lines[0], /^swagger-ui-dist \d+\.\d+\.\d+ \(Apache-2\.0\)/);
  const sums = lines.slice(1);
  assert.equal(sums.length, 4);
  for (const line of sums) {
    const [sum, file] = line.split(/\s+/);
    assert.equal(crypto.createHash('sha256').update(read(file)).digest('hex'), sum, file);
  }
  assert.ok(read('SWAGGER-UI-LICENSE').length > 0);
});

t('scripts come only from this folder, none inline', () => {
  const html = read('index.html').toString();
  assert.match(html, /Content-Security-Policy[^>]*script-src 'self';/);
  assert.match(html, /frame-ancestors 'none'/);
  const scripts = [...html.matchAll(/<script([^>]*)>([\s\S]*?)<\/script>/g)];
  assert.ok(scripts.length >= 2);
  for (const [, attrs, body] of scripts) {
    assert.equal(body.trim(), '', 'no inline script');
    assert.match(attrs, /src="[a-z0-9.-]+\.js"/, 'a local file, not a URL');
  }
  assert.doesNotMatch(html, /https?:\/\//, 'no external resource');
});

t('safe defaults: no validator, no injection, nothing persisted, PKCE', () => {
  assert.equal(SWAGGER_OPTIONS.validatorUrl, null);
  assert.equal(SWAGGER_OPTIONS.queryConfigEnabled, false);
  assert.equal(SWAGGER_OPTIONS.persistAuthorization, false);
  assert.equal(SWAGGER_OPTIONS.url, './openapi.json');
  assert.equal(OAUTH_OPTIONS.usePkceWithAuthorizationCodeGrant, true);
});

t('it serves the generated document, not a hand-kept copy', () => {
  const served = read('openapi.json').toString();
  const generated = fs.readFileSync(new URL('../../contracts/mcp/generated/openapi.json', import.meta.url)).toString();
  assert.equal(served, generated);
  assert.ok(JSON.parse(served).paths['/functions/v1/deskilo-mcp']);
});

console.log(`api docs: ${cases} cases passed`);

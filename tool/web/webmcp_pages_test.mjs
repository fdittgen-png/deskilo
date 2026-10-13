// SPDX-License-Identifier: AGPL-3.0-or-later
// W3 of #2500: the product page's and the welcome page's WebMCP tools, against
// a fake modelContext and no browser. Run by test/lint/webmcp_pages_test.dart.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { productTools, start, STRINGS, areaOf } from '../../web/product_webmcp.js';
import { TEXT, LOCALES } from '../../web/product.js';
import { CAPABILITIES } from '../../web/product_capabilities.js';

const read = (p) => fs.readFileSync(new URL('../../web/' + p, import.meta.url), 'utf8');
const webmcpSource = read('webmcp.js');
let cases = 0;
const t = async (name, fn) => { try { await fn(); } catch (e) { e.message = `${name}: ${e.message}`; throw e; } cases++; };

const fakeWindow = ({ supported = true, lang = 'en', extra = {} } = {}) => {
  const registered = new Map();
  let registerCalls = 0;
  const listeners = {};
  const select = { value: lang, addEventListener: (ev, fn) => { (listeners[ev] ??= []).push(fn); } };
  const doc = {
    documentElement: { getAttribute: () => select.value }, readyState: 'complete', getElementById: (id) => (id === 'lang' ? select : null),
    addEventListener() {}, querySelectorAll: () => [], ...extra.doc,
    ...(supported ? { modelContext: { registerTool(def, { signal }) { registerCalls++; registered.set(def.name, def); signal.addEventListener('abort', () => { if (registered.get(def.name) === def) registered.delete(def.name); }); return Promise.resolve(); } } } : {}),
  };
  const win = { document: doc, setTimeout: (fn) => fn(), location: { assign() {} }, ...extra.win };
  new Function('window', 'document', 'navigator', 'console', webmcpSource)(win, doc, {}, { debug() {} });
  return { win, select, listeners, registered, calls: () => registerCalls, run: (n, i = {}) => registered.get(n).execute(i, {}) };
};

// ------------------------------------------------------------ product page
const html = read('product.html');
await t('product: CSP unchanged, only the declared scripts, no network in the new code', () => {
  assert.match(html, /connect-src 'none'/);
  assert.match(html, /script-src 'self'/);
  const srcs = [...html.matchAll(/<script([^>]*)>/g)].map((m) => /src="([^"]+)"/.exec(m[1])[1]);
  assert.deepEqual(srcs, ['webmcp.js', 'product.js', 'product_webmcp.js']);
  for (const f of ['webmcp.js', 'product_webmcp.js', 'welcome/welcome_webmcp.js']) {
    assert.doesNotMatch(read(f), /\bfetch\s*\(|XMLHttpRequest|sendBeacon|WebSocket|\beval\s*\(|innerHTML/, f);
  }
});

for (const l of LOCALES) {
  await t(`product[${l}]: tools answer from the catalogue`, async () => {
    const tools = Object.fromEntries(productTools(l).map((x) => [x.name, x]));
    assert.deepEqual(Object.keys(tools), ['list_capabilities', 'get_capability', 'explain_product', 'list_audiences']);
    for (const x of Object.values(tools)) assert.equal(x.description, STRINGS[l][{ list_capabilities: 'list', get_capability: 'get', explain_product: 'explain', list_audiences: 'audiences' }[x.name]]);

    const all = tools.list_capabilities.execute({});
    assert.deepEqual(all.data.capabilities.map((c) => c.id), CAPABILITIES.map((c) => c.id));
    const pay = tools.list_capabilities.execute({ area: 'payments' }).data.capabilities.map((c) => c.id);
    assert.deepEqual(pay, CAPABILITIES.filter((c) => areaOf(c.id) === 'payments').map((c) => c.id));
    assert.ok(tools.list_capabilities.execute({ query: 'booking' }).data.capabilities.some((c) => c.id === 'booking'));

    const one = tools.get_capability.execute({ id: 'booking' }).data;
    const cat = CAPABILITIES.find((c) => c.id === 'booking');
    assert.ok(cat.outcome.length > 20);
    assert.equal(one.outcome, cat.outcome);
    assert.equal(one.name, TEXT[l].cap_booking);
    assert.equal(one.text_language, 'en');
    const missing = tools.get_capability.execute({ id: 'nope' });
    assert.equal(missing.error.code, 'not_found');
    assert.ok(missing.error.allowed.includes('booking'));

    // An answer is catalogue content and nothing else: each line is name,
    // state and the manifest's outcome, and the ids say which.
    const answer = tools.explain_product.execute({ topic: 'payments' }).data;
    assert.ok(answer.capability_ids.includes('payments.stripe'));
    const lines = answer.answer.split('\n');
    assert.equal(lines.length, answer.capability_ids.length);
    answer.capability_ids.forEach((id, i) => {
      const c = CAPABILITIES.find((x) => x.id === id);
      assert.ok(lines[i].endsWith(`: ${c.outcome}`), lines[i]);
      assert.ok(lines[i].startsWith(TEXT[l][`cap_${id.replace(/\./g, '_')}`]), lines[i]);
    });
    const aud = tools.list_audiences.execute({}).data.audiences;
    assert.deepEqual(aud.map((a) => a.text), [TEXT[l].roleOwner, TEXT[l].roleDba, TEXT[l].roleOperator, TEXT[l].roleMember]);
  });
}

await t('product: unsupported environment is a no-op; supported registers once and follows the language', () => {
  const none = fakeWindow({ supported: false });
  assert.equal(start(none.win), null);
  assert.equal(none.registered.size, 0);
  const w = fakeWindow({ lang: 'en' });
  assert.equal(typeof start(w.win), 'function');
  assert.equal(w.registered.size, 4);
  assert.equal(w.calls(), 4);
  const en = w.registered.get('list_capabilities').description;
  w.select.value = 'de';
  w.listeners.change.forEach((fn) => fn());
  assert.equal(w.registered.size, 4);
  assert.equal(w.calls(), 8);
  assert.equal(w.registered.get('list_capabilities').description, STRINGS.de.list);
  assert.notEqual(en, STRINGS.de.list);
});

// ------------------------------------------------------------ welcome page
const welcome = read('welcome/index.html');
const entries = [...welcome.matchAll(/<a [^>]*data-entry="(\w+)"[^>]*>/g)].map((m) => ({
  id: m[1], href: /href="([^"]+)"/.exec(m[0])[1], textContent: ' Label of ' + m[1] + ' ', getAttribute: (k) => (k === 'data-entry' ? m[1] : null),
}));

await t('welcome: CSP unchanged and the declared scripts', () => {
  assert.match(welcome, /connect-src 'none'/);
  assert.match(welcome, /script-src 'self'/);
  const srcs = [...welcome.matchAll(/<script[^>]*src="([^"]+)"/g)].map((m) => m[1]);
  assert.deepEqual(srcs, ['i18n.js', 'welcome.js', '../webmcp.js', 'welcome_webmcp.js']);
  assert.deepEqual([...new Set(entries.map((e) => e.id))].sort(), ['app', 'demo', 'guide', 'product', 'setup']);
});

function welcomePage(opts = {}) {
  const calls = [];
  const w = fakeWindow({ supported: opts.supported, lang: 'fr', extra: {
    doc: { querySelectorAll: (sel) => (sel === 'a[data-entry]' ? opts.entries ?? entries : []), getElementById: () => ({ addEventListener() {} }) },
    win: { location: { assign: (u) => calls.push(u) } } } });
  new Function('window', fs.readFileSync(new URL('../../web/welcome/welcome_webmcp.js', import.meta.url), 'utf8'))(w.win);
  return { ...w, assigned: calls };
}

await t('welcome: unsupported environment is a no-op', () => {
  const p = welcomePage({ supported: false });
  assert.equal(p.registered.size, 0);
});

await t('welcome: list_entry_points and go_to follow only the listed targets', async () => {
  const p = welcomePage();
  assert.deepEqual([...p.registered.keys()], ['list_entry_points', 'go_to']);
  const list = (await p.run('list_entry_points')).data.entry_points;
  assert.deepEqual(list.map((e) => e.id).sort(), ['app', 'demo', 'guide', 'product', 'setup']);
  for (const e of list) assert.ok(e.url.startsWith('https://'));
  const ok = await p.run('go_to', { id: 'demo' });
  assert.equal(ok.ok, true);
  assert.deepEqual(p.assigned, [list.find((e) => e.id === 'demo').url]);
  for (const bad of ['javascript:alert(1)', 'https://evil.example/', 'DEMO', '', 5]) {
    const r = await p.run('go_to', { id: bad });
    assert.equal(r.ok, false, String(bad));
    assert.equal(r.error.code, 'not_found');
    assert.ok(r.error.allowed.includes('demo'));
  }
  assert.equal(p.assigned.length, 1, 'nothing else was followed');
});

await t('welcome: a non-https link is never offered', async () => {
  const p = welcomePage({ entries: [{ href: 'javascript:alert(1)', textContent: 'x', getAttribute: () => 'evil' }, ...entries] });
  const ids = (await p.run('list_entry_points')).data.entry_points.map((e) => e.id);
  assert.ok(!ids.includes('evil'));
});

console.log(`webmcp pages: ${cases} cases ok`);

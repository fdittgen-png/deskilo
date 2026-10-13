// The user guide's WebMCP tools against a fake modelContext (W2 of #2500).
// Run by test/lint/guide_webmcp_test.dart; prints "guide webmcp: ok" at the end.
import fs from 'fs';

const root = new URL('../../web/', import.meta.url);
const read = (p) => fs.readFileSync(new URL(p, root), 'utf8');
const LANGS = ['en', 'fr', 'de', 'es', 'it'];
const webmcp = read('webmcp.js');
const tools = read('guide/guide_webmcp.js');
const guideJs = read('guide/guide.js');
let failed = 0;
const fail = (m) => { failed++; console.log('FAIL ' + m); };

// The reader levels, straight from guide.js.
const ladder = new Function('return ' + /var ladder = (\{[\s\S]*?\n  \});/.exec(guideJs)[1])();

const plain = (html) => html
  .replace(/<\/(p|li|h[1-6]|blockquote|tr|div|ol|ul)>|<br\s*\/?>/gi, ' ')
  .replace(/<[^>]*>/g, '')
  .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&#x27;/g, "'").replace(/&amp;/g, '&')
  .replace(/\s+/g, ' ').trim();

// webmcp.js and the tools share one scope, as two script tags share the page's.
const run = (lang, opts) => {
  const registered = new Map();
  const appended = [];
  const ctx = { registerTool(def) { registered.set(def.name, def); return Promise.resolve(); } };
  const win = { GuideState: { ladder, level: () => opts?.level ?? 'everything' }, location: { href: `https://example.test/guide/${lang}.html` } };
  const doc = {
    documentElement: { lang }, body: { getAttribute: (k) => (k === 'data-book' ? (opts?.book ?? 'user') : null) },
    createElement: () => ({}),
    head: { appendChild(tag) { appended.push(tag.src); Function('window', read('guide/' + tag.src))(win); tag.onload(); } },
    ...(opts?.supported === false ? {} : { modelContext: ctx }),
  };
  Function('window', 'document', 'navigator', 'console', webmcp)(win, doc, {}, { debug() {} });
  globalThis.__win = win;
  Function('window', 'document', 'navigator', 'console', tools)(win, doc, {}, { debug() {} });
  return { registered, appended, call: (n, i = {}) => registered.get(n).execute(i, {}) };
};

const CSP = "default-src 'none'; img-src 'self' data:; style-src 'self'; script-src 'self'; base-uri 'none'; form-action 'none'";
const names = ['search_guide', 'get_section', 'list_sections', 'list_roles'];

for (const lang of LANGS) {
  // Unsupported: no tool, no index loaded, no throw.
  const none = run(lang, { supported: false });
  if (none.registered.size || none.appended.length) fail(`[${lang}] an unsupported browser registered or loaded something`);

  const g = run(lang);
  if (g.appended.join() !== `guide_index_${lang}.js`) fail(`[${lang}] the page's own index was not the one loaded: ${g.appended}`);
  if (JSON.stringify([...g.registered.keys()]) !== JSON.stringify(names)) fail(`[${lang}] tools: ${[...g.registered.keys()]}`);

  const all = (await g.call('list_sections')).data.sections;
  if (!all.length) fail(`[${lang}] empty index`);
  const html = { user: read(`guide/${lang}.html`), setup: read(`guide/setup-${lang}.html`) };
  for (const h of Object.values(html)) if (!h.includes(CSP)) fail(`[${lang}] the page CSP changed`);

  // Every entry: its anchor exists in the page, and its text is the page's.
  let checked = 0;
  for (const s of all) {
    const page = html[s.family];
    const m = new RegExp(`<article class="section[^"]*" id="${s.id.replace(/\./g, '\\.')}"[\\s\\S]*?<div class="body">([\\s\\S]*?)</div>(?:<div class="media">[\\s\\S]*?)?</article>`).exec(page);
    if (!m) { fail(`[${lang}] ${s.id} is not an article of ${s.family}`); continue; }
    const got = (await g.call('get_section', { id: s.id })).data;
    if (got.text !== plain(m[1])) fail(`[${lang}] ${s.id}: text differs from the page`);
    if (!got.url.endsWith(`${s.family === 'user' ? lang : s.family + '-' + lang}.html#${s.id}`)) fail(`[${lang}] ${s.id}: url ${got.url}`);
    checked++;
  }

  // A question: the title of a section finds that section's id.
  const probe = (await g.call('get_section', { id: all[Math.floor(all.length / 2)].id })).data;
  const hit = await g.call('search_guide', { query: probe.title, role: 'everything', book: probe.family, limit: 3 });
  if (!hit.ok || !hit.data.results.some((r) => r.id === probe.id)) fail(`[${lang}] searching "${probe.title}" does not return ${probe.id}`);
  const bad = await g.call('search_guide', { query: '  ' });
  if (bad.ok || bad.error.code !== 'validation_error') fail(`[${lang}] an empty query is not a validation_error`);

  // Unknown id: not_found with suggestions.
  const nf = await g.call('get_section', { id: probe.id + '.zzz' });
  if (nf.ok || nf.error.code !== 'not_found' || !nf.error.suggestions?.length) fail(`[${lang}] unknown id: ${JSON.stringify(nf).slice(0, 120)}`);

  // Another language is not offered in v1 and says so.
  const other = await g.call('search_guide', { query: probe.title, language: LANGS.find((l) => l !== lang) });
  if (other.ok || other.error.code !== 'unsupported_language') fail(`[${lang}] another language was not refused`);

  // The page's level filter holds unless a role is passed.
  const member = run(lang, { level: 'member' });
  const shown = (await member.call('list_sections')).data.sections;
  if (shown.some((s) => !s.roles.some((r) => ladder.member.includes(r)))) fail(`[${lang}] the member level leaks other audiences`);
  const wide = (await member.call('list_sections', { role: 'everything' })).data.sections;
  if (wide.length <= shown.length) fail(`[${lang}] an explicit role does not widen the list`);
  const roles = (await member.call('list_roles')).data;
  if (roles.current !== 'member' || roles.levels.length !== Object.keys(ladder).length) fail(`[${lang}] list_roles`);
  console.log(`[${lang}] ${checked} sections checked`);
}

// No network from any tool; the module has none either.
for (const [file, src] of [['webmcp.js', webmcp], ['guide_webmcp.js', tools]]) {
  if (/\bfetch\s*\(|XMLHttpRequest|WebSocket|sendBeacon|\bimport\s*\(|localStorage|sessionStorage/.test(src)) fail(`${file} reaches for network or storage`);
}
if (failed) { console.log(`${failed} failure(s)`); process.exit(1); }
console.log('guide webmcp: ok');

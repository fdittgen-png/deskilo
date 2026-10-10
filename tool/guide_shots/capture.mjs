// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Re-shoots the user guide's screenshots from a built web app, in the Demo
// workspace, in every guide language. Everything a shot needs is in
// shots.json — a new build, a changed screen or a new language is one run.
//
//   npm i playwright-core                       (once, in a scratch directory)
//   flutter build web --release -o /tmp/guide-web
//   node tool/guide_shots/capture.mjs --web /tmp/guide-web [--lang fr,de] [--only reserve]
//
// Output: docs/wiki/images/<id>.<lang>.jpg — the id is the guide anchor with
// its dots turned into dashes (docs/wiki/User-Guide.md), `--<part>` names a
// cut-out, and the language is the last name segment. Re-shooting overwrites
// the file, so no link in any guide changes.
import { createRequire } from 'module';
import http from 'http';
import fs from 'fs';
import path from 'path';

const require = createRequire(process.env.PW_DIR ? process.env.PW_DIR + '/' : import.meta.url);
const { chromium } = require('playwright-core');

const argv = process.argv.slice(2);
const opt = (n, d) => { const i = argv.indexOf('--' + n); return i < 0 ? d : argv[i + 1]; };
const root = path.resolve(opt('web', 'build/web'));
const outDir = path.resolve(opt('out', 'docs/wiki/images'));
const langs = opt('lang', 'en,fr,de,es,it').split(',');
const only = opt('only', '').split(',').filter(Boolean);
// 1.2 device pixels and quality 62 keep a screenshot near 20 KB: the in-app help bundles five languages of them.
const quality = Number(opt('quality', '62'));
const repo = path.resolve(opt('repo', '.'));
// One file per guide chapter: tool/guide_shots/shots/<chapter>.json
const shotsDir = path.join(repo, 'tool/guide_shots/shots');
const chapters = opt('chapter', '').split(',').filter(Boolean);
const spec = { shots: fs.readdirSync(shotsDir).filter(f => f.endsWith('.json') && (!chapters.length || chapters.some(c => f.startsWith(c))))
  .sort().flatMap(f => JSON.parse(fs.readFileSync(path.join(shotsDir, f), 'utf8')).shots) };
// The build the shots were taken from is part of every file name:
// <id>[--part].<lang>.b<commit>.jpg — a re-shoot from a newer build writes a
// new name, rewrites the guides' references to it and removes the old file.
import { execSync } from 'child_process';
const sha = opt('build', execSync('git rev-parse --short=8 HEAD', { cwd: opt('repo', '.') }).toString().trim());
const version = (() => { try { const v = JSON.parse(fs.readFileSync(path.join(root, 'version.json'), 'utf8')); return `${v.version}+${v.build_number}`; } catch { return 'unknown'; } })();
const stamp = `b${sha}`;
const taken = new Date().toISOString().slice(0, 10);
const made = [];
const LOCALE = { en: 'en-US', fr: 'fr-FR', de: 'de-DE', es: 'es-ES', it: 'it-IT' };
const VIEW = { phone: [390, 844], tablet: [820, 1100], desktop: [1280, 860] };
const PERSONA = { owner: 'demoPersonaOwner', admin: 'demoPersonaAdmin', member: 'demoPersonaMember' };

const mime = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.css': 'text/css' };
const server = http.createServer((q, r) => {
  const p = decodeURIComponent(q.url.split('?')[0]);
  let f = path.join(root, p);
  if (!fs.existsSync(f) || fs.statSync(f).isDirectory()) f = path.join(root, 'index.html');
  r.writeHead(200, { 'content-type': mime[path.extname(f)] || 'application/octet-stream' });
  fs.createReadStream(f).pipe(r);
}).listen(0);
const port = server.address().port;

const exe = opt('chrome', process.env.HOME + '/Library/Caches/ms-playwright/chromium_headless_shell-1208/chrome-headless-shell-mac-arm64/chrome-headless-shell');
const browser = await chromium.launch({ executablePath: exe, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });

const ROLES = '[role=button],[role=tab],[role=menuitem],[role=link],[role=checkbox],[role=switch],[role=radio],[role=option],[role=menuitemradio]';
const esc = s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const sleep = (p, ms) => p.waitForTimeout(ms);
let failures = 0;

for (const lang of langs) {
  const arb = JSON.parse(fs.readFileSync(path.join(repo, `lib/l10n/app_${lang}.arb`), 'utf8'));
  const t = k => { const v = arb[k]; if (typeof v !== 'string') throw new Error(`no string ${k} in ${lang}`); return v; };
  // `@key` is an ARB string; `@key|name=Ada;count=3` fills its {placeholders}.
  const txt = s => {
    if (typeof s !== 'string' || !s.startsWith('@')) return s;
    const [key, args] = s.slice(1).split('|');
    let out = t(key);
    for (const pair of (args ?? '').split(';').filter(Boolean)) { const [k, v] = pair.split('='); out = out.split(`{${k}}`).join(v); }
    return out;
  };
  let w = 0, h = 0, h0 = 0, ctx = null, page = null, persona = null;

  async function boot(view) {
    if (ctx) await ctx.close();
    [w, h] = VIEW[view]; h0 = h;
    ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: Number(opt('dpr', '1.2')), locale: LOCALE[lang] });
    page = await ctx.newPage();
    await page.goto(`http://localhost:${port}/`);
    await sleep(page, 9000);
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await sleep(page, 1200);
    await click(t('demoEntryAction'));
    await sleep(page, 2000);
    await click(t('demoEntryStart'));
    await sleep(page, 4500);
    persona = 'owner';
  }
  // The smallest semantics node whose label contains [label], as a box.
  async function locate(label, nth = 0) {
    // An array is "any of these": a literal that differs per language lists them all.
    if (Array.isArray(label)) {
      // Lists are written English first; in another language try the English last,
      // or its short word matches a longer one ("Plan" inside "Planta").
      const order = lang === 'en' ? label : [...label.slice(1), label[0]];
      for (const one of order) { try { return await locate(txt(one), nth); } catch { /* try the next */ } }
      throw new Error(`nothing found: any of ${JSON.stringify(label)} (${lang})`);
    }
    const boxes = await page.evaluate(([x]) => {
      const lc = x.toLowerCase();
      return [...document.querySelectorAll('flt-semantics')]
        .map(e => ({ t: (e.getAttribute('aria-label') || e.textContent || '').toLowerCase(), r: e.getBoundingClientRect() }))
        .filter(o => o.t.includes(lc) && o.r.width > 0 && o.r.height > 0)
        .map(o => ({ x: o.r.x, y: o.r.y, width: o.r.width, height: o.r.height, len: o.t.length }))
        .sort((a, b) => a.len - b.len || a.y - b.y);
    }, [label]);
    if (!boxes.length) throw new Error(`nothing found: "${label}" (${lang})`);
    return boxes[Math.min(nth, boxes.length - 1)];
  }
  // A static page of the web build (the setup wizard): no demo, plain DOM.
  async function bootPlain(view, url) {
    if (ctx) await ctx.close();
    [w, h] = VIEW[view]; h0 = h;
    ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: Number(opt('dpr', '1.2')), locale: LOCALE[lang] });
    page = await ctx.newPage();
    await page.goto(`http://localhost:${port}${url.replace('{lang}', lang)}`);
    await sleep(page, 2500);
    persona = null;
  }
  async function click(label, nth = 0) {
    const box = await locate(Array.isArray(label) ? label.map(txt) : label, nth);
    await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
  }
  // The demo bar's chip is not a menu: each tap moves to the next persona
  // (owner -> member -> administrator -> owner) and the chip names the one in use.
  const CYCLE = ['owner', 'member', 'admin'];
  async function setPersona(p) {
    for (let i = 0; i < CYCLE.length && persona !== p; i++) {
      await click(t(PERSONA[persona]));
      await sleep(page, 3500);
      persona = CYCLE[(CYCLE.indexOf(persona) + 1) % CYCLE.length];
    }
    if (persona !== p) throw new Error(`could not switch to ${p}`);
  }
  async function run(steps) {
    for (const s of steps) {
      if (s.hash) { await page.evaluate(x => { location.hash = x; }, s.hash); await sleep(page, s.wait ?? 3200); }
      else if (s.click) {
        const target = Array.isArray(s.click) ? s.click : txt(s.click);
        // `via`: a tab that does not fit the row lives behind the overflow button.
        if (s.via) { try { await click(target, s.nth ?? 0); } catch { await click(s.via); await sleep(page, 700); await click(target, s.nth ?? 0); } }
        else await click(target, s.nth ?? 0); await sleep(page, s.wait ?? 1400); }
      else if (s.at) { const top = await topOfApp(); await page.mouse.click(s.at[0], top + s.at[1]); await sleep(page, s.wait ?? 1400); }
      else if (s.type) { await page.keyboard.type(s.type, { delay: 40 }); await sleep(page, 500); }
      else if (s.fill) { const [label, value] = s.fill; await page.getByLabel(new RegExp(esc(txt(label)), 'i')).first().fill(txt(value)); await sleep(page, 500); }
      else if (s.scroll != null) { await page.mouse.move(w / 2, h / 2); await page.mouse.wheel(0, s.scroll); await sleep(page, s.wait ?? 900); }
      else if (s.press) { await page.keyboard.press(s.press); await sleep(page, 700); }
      else if (s.css) { await page.locator(s.css).first().click(); await sleep(page, s.wait ?? 900); }
      else if (s.eval) { await page.evaluate(s.eval); await sleep(page, s.wait ?? 600); }
      else if (s.wait) await sleep(page, s.wait);
      else throw new Error('unknown step ' + JSON.stringify(s));
    }
  }
  // The demo banner sits above the app; every shot starts below it.
  async function topOfApp() {
    let bottom = 0;
    for (const k of ['demoSessionLeave', 'demoSessionReset']) {
      const loc = page.locator(ROLES).filter({ hasText: new RegExp(esc(t(k)), 'i') });
      if (await loc.count()) { const r = await loc.first().boundingBox(); if (r) bottom = Math.max(bottom, r.y + r.height); }
    }
    return bottom ? Math.ceil(bottom) + 8 : 0;
  }
  // A tip is a help bubble over the content: click it away, never shoot it.
  async function clearTips() {
    for (const label of [t('helpHintDismiss'), t('gettingStartedNotNow')]) {
      for (let i = 0; i < 8; i++) {
        const loc = page.locator(ROLES).filter({ hasText: new RegExp(esc(label), 'i') });
        if (await loc.count() === 0) break;
        const box = await loc.first().boundingBox().catch(() => null);
        if (box) await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
        await sleep(page, 500);
      }
    }
  }
  // A form that is still loading is work in progress: wait for the spinners
  // to go and for two renders, 700 ms apart, to come out byte-identical.
  async function settle(keepTips = false) {
    if (!keepTips) await clearTips();
    let prev = null;
    for (let i = 0; i < 24; i++) {
      const busy = await page.locator('[role=progressbar]:not([aria-valuenow])').count();
      const frame = await page.screenshot({ type: 'jpeg', quality: 40 });
      if (!busy && prev && frame.equals(prev)) return;
      prev = frame;
      await sleep(page, 700);
    }
    throw new Error('never settled (still moving or loading)');
  }
  // Grow the window until the screen no longer scrolls, so a long form is
  // shot whole. Returns a function that puts the window back.
  async function grow() {
    const extent = () => page.evaluate(() => Math.max(0, ...[...document.querySelectorAll('flt-semantics')].map(e => e.scrollHeight - e.clientHeight)));
    for (let i = 0; i < 3; i++) {
      const ext = await extent();
      if (ext < 8) break;
      // A browser canvas is blank beyond 8192 device pixels: never grow past that.
      const cap = Math.floor(8000 / Number(opt('dpr', '1.2')));
      h = Math.min(h + ext + 40, cap);
      await page.setViewportSize({ width: w, height: h });
      await sleep(page, 1500);
    }
  }
  async function shoot(file, clip) {
    const top = await topOfApp();
    const c = clip ? [clip[0], clip[1] + top, clip[2], clip[3]] : [0, top, w, h - top];
    await page.screenshot({ path: file, type: 'jpeg', quality, clip: { x: c[0], y: c[1], width: c[2], height: c[3] } });
  }
  function name(id, partId) { return path.join(outDir, `${id}${partId ? '--' + partId : ''}.${lang}.${stamp}.jpg`); }
  // Where a part starts or ends: a label on screen, relative to the app.
  async function yOf(label, top, pad = 10) {
    const box = await locate(Array.isArray(label) ? label.map(txt) : txt(label));
    return Math.max(0, Math.floor(box.y - top - pad));
  }
  async function part(file, p, top) {
    if (p.steps) await run(p.steps);
    if (p.from || p.to) {
      const y0 = p.from ? await yOf(p.from, top, p.pad ?? 10) : 0;
      const y1 = p.to ? await yOf(p.to, top, p.pad ?? 10) : h - top;
      await shoot(file, [0, y0, w, Math.max(40, y1 - y0)], true);
    } else await shoot(file, p.clip, true);
  }

  let view = null;
  for (const sh of spec.shots) {
    if (only.length && !only.some(o => sh.id.includes(o))) continue;
    for (let attempt = 1; attempt <= 2; attempt++) try {
      if (sh.url) {
        view = sh.view ?? 'phone'; await bootPlain(view, sh.url);
        await run(sh.steps ?? []);
      } else {
        if (sh.view !== view || sh.fresh) { view = sh.view ?? 'phone'; await boot(view); }
        await setPersona(sh.persona ?? 'owner');
        await run(sh.steps ?? []);
        await settle(sh.keepTips);
        if (sh.full !== false) await grow();
        await settle(sh.keepTips);
      }
      if (process.env.GUIDE_SHOTS_DEBUG) await page.screenshot({ path: path.join(process.env.TMPDIR || '/tmp', `guide-shots-debug-${sh.id}.${lang}.png`) });
      const top = await topOfApp();
      if (sh.clip !== false) await shoot(name(sh.id), sh.clip, true);
      for (const p of sh.parts ?? []) await part(name(sh.id, p.id), p, top);
      await page.setViewportSize({ width: w, height: (h = h0) });
      made.push({ id: sh.id, lang, file: path.basename(name(sh.id)), parts: (sh.parts ?? []).map(p => path.basename(name(sh.id, p.id))), persona: sh.persona ?? 'owner', view: sh.view ?? 'phone', build: sha, version, taken, shows: sh.shows ?? '' });
      console.log(`${lang} ok   ${sh.id}`);
      break;
    } catch (e) {
      view = null; // a failed step leaves the app in an unknown place: start clean
      if (attempt === 2 && page) await page.screenshot({ path: path.join(process.env.TMPDIR || '/tmp', `guide-shots-fail-${sh.id}.${lang}.png`) }).catch(() => {});
      if (attempt === 2) { failures++; console.log(`${lang} FAIL ${sh.id}: ${e.message.split('\n')[0]}`); }
    }
  }
  if (ctx) await ctx.close();
}
await browser.close();
server.close();

// Bookkeeping: one manifest per language (languages are shot in parallel),
// and the files of builds this run superseded are removed. The guides keep
// writing the logical name; tool/build_user_guide.dart resolves it.
for (const lang of langs) {
  const mine = made.filter(m => m.lang === lang);
  if (!mine.length) continue;
  const file = path.join(outDir, `_shots.${lang}.json`);
  const manifest = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : { shots: [] };
  for (const m of mine) manifest.shots = manifest.shots.filter(o => o.id !== m.id);
  manifest.shots.push(...mine);
  manifest.shots.sort((a, b) => a.id.localeCompare(b.id));
  fs.writeFileSync(file, JSON.stringify(manifest, null, 1) + '\n');
}
const current = new Set(made.flatMap(m => [m.file, ...m.parts]));
for (const f of fs.readdirSync(outDir)) {
  const m = f.match(/^(.*\.(?:en|fr|de|es|it))\.b[0-9a-f]+\.jpg$/);
  if (!m || current.has(f)) continue;
  if ([...current].some(c => c.startsWith(m[1] + '.b'))) fs.unlinkSync(path.join(outDir, f));
}
process.exitCode = failures ? 1 : 0;

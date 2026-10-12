// SPDX-License-Identifier: AGPL-3.0-or-later
// Assembles public/ — the whole site this package serves. No dependencies.
//
//   Pages only, from a DesKilo checkout (no web app):
//     SITE_URL=https://www.example.com node build/build-site.mjs --src ../deskilo
//   Pages AND the web app, from a `flutter build web` output (what the CI does):
//     SITE_URL=https://www.example.com node build/build-site.mjs --web ../deskilo/build/web
//
//   --src <dir>   a DesKilo checkout (needs web/ and assets/help/images/)
//   --web <dir>   a Flutter web build (built with --base-href /): the app is the site's
//                 home, and the welcome page, guides and setup pages are already in it
//   SITE_URL      where THIS site will live, no trailing slash. Empty = relative
//   APP_URL       where the web app lives (default: SITE_URL/ with --web, else GitHub Pages)
//   SOURCE_SHA    the DesKilo commit, recorded in public/BUILD.txt
//
// What it does: copies the welcome page, the user guide, the setup guide, the
// setup questionnaire, the evaluation page, the privacy page and the API docs;
// copies only the guide images the pages reference; points the links that were
// written for GitHub Pages at SITE_URL (our pages) and APP_URL (the app);
// then fails if any relative link or image does not resolve.
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const out = resolve(here, '..', 'public');
const argv = process.argv.slice(2);
const flag = (n) => (argv.indexOf(n) < 0 ? null : argv[argv.indexOf(n) + 1] ?? '');
const webArg = flag('--web');
const srcArg = flag('--src');
if (!webArg && !srcArg) { console.error('usage: build-site.mjs (--web <flutter web build> | --src <deskilo checkout>)'); process.exit(2); }
const siteUrl = (process.env.SITE_URL ?? '').replace(/\/+$/, '');
const PAGES = 'https://fdittgen-png.github.io/deskilo/';
const appUrl = (process.env.APP_URL ?? (webArg ? `${siteUrl}/` : PAGES)).replace(/\/*$/, '/');

rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
const images = new Set();

if (webArg) {
  const web = resolve(webArg);
  for (const need of ['index.html', 'flutter_bootstrap.js', 'main.dart.js', 'welcome/index.html', 'guide/en.html', 'setup.html']) {
    if (!existsSync(join(web, need))) { console.error(`not a DesKilo web build: ${need} missing in ${web}`); process.exit(2); }
  }
  cpSync(web, out, { recursive: true });
} else {
  const src = resolve(srcArg);
  for (const need of ['web/welcome/index.html', 'web/guide/en.html', 'web/setup.html', 'assets/help/images']) {
    if (!existsSync(join(src, need))) { console.error(`not a DesKilo checkout: ${need} missing in ${src}`); process.exit(2); }
  }
  const copy = (from, to = from) => cpSync(join(src, from), join(out, to), { recursive: true });
  ['web/welcome', 'web/guide', 'web/api', 'web/setup_l10n', 'web/icons'].forEach((d) => copy(d, d.slice(4)));
  ['setup.html', 'setup_catalogue.js', 'setup_l10n.js', 'product.html', 'product.js', 'product_capabilities.js',
    'cost_planner.js', 'privacy.html', 'favicon.png'].forEach((f) => copy(`web/${f}`, f));
  // Only the screenshots the guide pages show (the app bundles all of them).
  for (const f of readdirSync(join(out, 'guide')).filter((n) => n.endsWith('.html'))) {
    for (const m of readFileSync(join(out, 'guide', f), 'utf8').matchAll(/assets\/assets\/help\/images\/([^"'\s)]+)/g)) images.add(m[1]);
  }
  for (const name of images) copy(`assets/help/images/${name}`, `assets/assets/help/images/${name}`);
}

// Links written for GitHub Pages. Our pages first, then what is left is the app.
const OURS = /https:\/\/fdittgen-png\.github\.io\/deskilo\/(?=welcome\/|guide\/|setup\.html|product\.html|privacy\.html|api\/)/g;
const APP = /https:\/\/fdittgen-png\.github\.io\/deskilo\//g;
const textual = /\.(html|css|json|txt)$/;
const textualJs = (p) => /\.js$/.test(p) && !/(^|\/)(main\.dart|canvaskit)[^/]*\.js$/.test(p) && !p.includes('/canvaskit/');
const walk = (d) => readdirSync(d).flatMap((n) => (statSync(join(d, n)).isDirectory() ? walk(join(d, n)) : [join(d, n)]));
// The setup guides cross-link each other by their wiki page names; on the site those are the setup-<lang>.html pages.
const WIKI = { 'Setup-Guide': 'setup-en.html', 'Guide-de-demarrage': 'setup-fr.html', 'Einrichtungsanleitung': 'setup-de.html',
  'Guia-de-puesta-en-marcha': 'setup-es.html', 'Guida-di-avvio': 'setup-it.html' };
const WIKI_LINK = new RegExp(`(href=")(${Object.keys(WIKI).join('|')})(?=[#"])`, 'g');
let rewritten = 0;
// The app's offline snapshot (task_tool_manifest) pins a checksum for these: they are never touched.
const pinned = (p) => { const r = relative(out, p).split('\\').join('/');
  return /^(assets|canvaskit|icons)\//.test(r) || ['index.html', 'manifest.json', 'version.json', 'flutter_bootstrap.js', 'flutter.js'].includes(r); };
for (const f of walk(out).filter((p) => (textual.test(p) || textualJs(p)) && !pinned(p))) {
  const before = readFileSync(f, 'utf8');
  const after = before.replace(OURS, `${siteUrl}/`).replace(APP, appUrl).replace(WIKI_LINK, (_, h, n) => h + WIKI[n]);
  if (after !== before) { writeFileSync(f, after); rewritten++; }
}

// Every relative reference must resolve — a deploy that 404s its own images is worse than no deploy.
const missing = [];
for (const f of walk(out).filter((p) => p.endsWith('.html'))) {
  const html = readFileSync(f, 'utf8');
  for (const m of html.matchAll(/\b(?:href|src)="([^"]+)"/g)) {
    const ref = m[1].split(/[?#]/)[0];
    if (!ref || /^([a-z][a-z0-9+.-]*:|\/\/|#)/i.test(m[1]) || ref.startsWith('/') || /['+]/.test(ref)) continue;
    const target = resolve(dirname(f), ref);
    if (!existsSync(target) && !existsSync(join(target, 'index.html'))) missing.push(`${relative(out, f)} -> ${m[1]}`);
  }
}
const size = walk(out).reduce((n, p) => n + statSync(p).size, 0);
console.log(`public/: ${walk(out).length} files, ${(size / 1048576).toFixed(1)} MB, ${images.size} guide images, ${rewritten} files re-pointed`);
console.log(`site ${siteUrl || '(relative)'} · app ${appUrl} · ${webArg ? 'with the web app' : 'pages only'}`);
writeFileSync(join(out, 'BUILD.txt'), [`source: fdittgen-png/deskilo@${process.env.SOURCE_SHA || '(unknown)'}`,
  `built: ${new Date().toISOString()}`, `site_url: ${siteUrl || '(relative)'}`, `app_url: ${appUrl}`, `mode: ${webArg ? 'pages + web app' : 'pages only'}`, ''].join('\n'));
if (missing.length) { console.error(`\n${missing.length} unresolved reference(s):\n  ${[...new Set(missing)].slice(0, 30).join('\n  ')}`); process.exit(1); }

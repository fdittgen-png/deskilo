// SPDX-License-Identifier: AGPL-3.0-or-later
// #1635: real Chromium layout, focus traversal and planner interactions.
// Node 24 LTS: npm ci --prefix tool/web
// npx --prefix tool/web playwright install chromium --only-shell
// npm --prefix tool/web run test:browser
// Optional DESKILO_WEB_ROOT points at the built web artifact; source static
// assets are otherwise served unchanged. No Flutter/Demo runtime claim.
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';
import { TEXT, LOCALES } from '../../web/product.js';

const root = process.env.DESKILO_WEB_ROOT ?? fileURLToPath(new URL('../../web', import.meta.url));
const files = new Set(['product.html', 'product.js', 'cost_planner.js', 'product_capabilities.js']);
const server = createServer(async (req, res) => {
  const name = new URL(req.url, 'http://localhost').pathname.replace(/^\/(nested\/)?/, '');
  if (!files.has(name)) { res.writeHead(404).end(); return; }
  try {
    res.setHeader('Content-Type', name.endsWith('.js') ? 'text/javascript' : 'text/html');
    res.end(await readFile(resolve(root, name)));
  } catch { res.writeHead(404).end(); }
});
await new Promise((ok) => server.listen(0, '127.0.0.1', ok));
const origin = `http://127.0.0.1:${server.address().port}`;
let browser;
let cases = 0;
const failures = [];

async function keyboardTo(page, selector) {
  for (let i = 0; i < 80; i++) {
    await page.keyboard.press('Tab');
    if (await page.locator(selector).evaluate((el) => el === document.activeElement)) return;
  }
  assert.fail(`unreachable by Tab: ${selector}`);
}

async function check(page, locale, scale) {
  const t = TEXT[locale];
  await page.waitForFunction((l) => document.documentElement.lang === l &&
    document.querySelector('#caps tr'), locale);
  if (scale === 2) await page.addStyleTag({ content: 'html{font-size:200%}' });
  assert.equal(await page.getByRole('combobox', { name: t.language, exact: true }).count(), 1);
  assert.equal(await page.getByRole('status').getAttribute('aria-live'), 'polite');
  const overflow = await page.evaluate(() => ({
    viewport: innerWidth, width: document.documentElement.scrollWidth,
    clipped: [...document.querySelectorAll('input,select,button,a,table,fieldset')]
      .filter((el) => { const r = el.getBoundingClientRect(); return r.width && (r.left < -1 || r.right > innerWidth + 1); })
      .map((el) => el.id || el.name || el.tagName),
  }));
  assert.ok(overflow.width <= overflow.viewport + 1, JSON.stringify(overflow));
  assert.deepEqual(overflow.clipped, [], JSON.stringify(overflow));

  // Real Tab traversal, including backwards movement and visible focus, with
  // no locator.focus() masking an unreachable control. No positive tabindex.
  const controls = page.locator('a,button,input,select');
  const count = await controls.count();
  for (let i = 0; i < count; i++) {
    await page.keyboard.press('Tab');
    // Chromium exposes date segments as separate native Tab stops with
    // the same input as document.activeElement. Keep them; skip no control.
    if (i > 0 && await controls.nth(i - 1).getAttribute('type') === 'date') {
      for (let n = 0; n < 5 && await controls.nth(i - 1).evaluate((el) => el === document.activeElement); n++) {
        await page.keyboard.press('Tab');
      }
    }
    assert.equal(await controls.nth(i).evaluate((el) => el === document.activeElement), true, `Tab ${i}`);
    assert.equal(await controls.nth(i).evaluate((el) => el.matches(':focus-visible') &&
      getComputedStyle(el).outlineStyle !== 'none'), true, `focus indicator ${i}`);
  }
  await page.keyboard.press('Shift+Tab');
  assert.equal(await controls.nth(count - 2).evaluate((el) => el === document.activeElement), true);
  await keyboardTo(page, '[name=backend_plan]');
  await page.keyboard.type('25');
  await page.waitForFunction(() => document.querySelector('#result').textContent.includes('25'));
  const money = new Intl.NumberFormat(locale, { style: 'currency', currency: 'EUR' }).format(25);
  assert.ok((await page.getByRole('status').innerText()).includes(money));

  await keyboardTo(page, '#save');
  const downloadPromise = page.waitForEvent('download');
  await page.keyboard.press('Enter');
  const download = await downloadPromise;
  assert.equal(download.suggestedFilename(), 'deskilo-cost-scenario.json');
  const saved = await readFile(await download.path());
  assert.equal(JSON.parse(saved).components.find((c) => c.id === 'backend_plan').amount, 25);
  await keyboardTo(page, '#reset');
  await page.keyboard.press('Enter');
  assert.equal(await page.locator('[name=backend_plan]').inputValue(), '');
  await keyboardTo(page, '#load');
  const chooserPromise = page.waitForEvent('filechooser');
  await page.keyboard.press('Space');
  const chooser = await chooserPromise;
  await chooser.setFiles({ name: 'scenario.json', mimeType: 'application/json', buffer: saved });
  await page.waitForFunction(() => document.querySelector('[name=backend_plan]').value === '25');
  assert.ok((await page.getByRole('status').innerText()).includes(money));
  await page.locator('#load').setInputFiles({ name: 'bad.json', mimeType: 'application/json', buffer: Buffer.from('{"version":999}') });
  await page.waitForFunction((s) => document.querySelector('#result').textContent === s, t.loadFailed);
  assert.equal(await page.locator('[name=backend_plan]').inputValue(), '25', 'bad import preserves input');
  for (const id of ['go-demo', 'go-signin', 'go-join']) {
    const href = await page.locator(`#${id}`).evaluate((el) => el.href);
    assert.equal(href, new URL('./#/auth', page.url()).href);
  }
}

try {
  browser = await chromium.launch();
  console.log(`Chromium ${browser.version()}; static root ${root}`);
  for (const base of ['/', '/nested/']) for (const locale of LOCALES) {
    for (const [width, scale] of [[320, 1], [320, 2], [960, 1]]) {
      const context = await browser.newContext({ locale, viewport: { width, height: 800 }, reducedMotion: 'reduce' });
      const page = await context.newPage();
      page.setDefaultTimeout(15000);
      const errors = [];
      page.on('pageerror', (e) => errors.push(e.message));
      await context.route('**/*', (route) => {
        if (!route.request().url().startsWith(origin + '/')) {
          errors.push('external request'); return route.abort();
        }
        return route.continue();
      });
      try {
        await page.goto(`${origin}${base}product.html`);
        await check(page, locale, scale);
        assert.deepEqual(errors, []);
        cases++;
      } catch (e) { failures.push(`${base} ${locale} ${width}px ${scale}x: ${e.message}`); }
      finally { await context.close(); }
    }
  }
  assert.deepEqual(failures, []);
  assert.equal(cases, 30);
  console.log(`product browser: ${cases} cases passed (five locales, root/nested, 320/960 px, 2x text, keyboard, save/load/reset, reduced motion)`);
} finally {
  await browser?.close();
  await new Promise((ok) => server.close(ok));
}

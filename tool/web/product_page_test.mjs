// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1635 — the evaluation page's contract, without a browser: every word
// in five languages, no network and no foreign script, entry links that
// only open the app's own sign-in screen, and the planner form's
// numbers checked by hand.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { TEXT, LOCALES, fieldValue, scenarioFromFields, describePlan, capabilityState, capabilityKey, capabilityRows } from '../../web/product.js';
import { CAPABILITIES } from '../../web/product_capabilities.js';
import { planCost } from '../../web/cost_planner.js';

const html = fs.readFileSync(new URL('../../web/product.html', import.meta.url), 'utf8');
let cases = 0;
const t = (name, fn) => { fn(); cases++; };

t('every locale has every word, and the page uses no word it lacks', () => {
  const keys = Object.keys(TEXT.en).sort();
  assert.deepEqual(LOCALES, ['en', 'fr', 'de', 'es', 'it']);
  for (const l of LOCALES) {
    assert.deepEqual(Object.keys(TEXT[l]).sort(), keys, l);
    for (const k of keys) assert.ok(TEXT[l][k].trim().length > 0 || k === 'colon', `${l}.${k}`);
  }
  const used = [...html.matchAll(/data-i18n="([^"]+)"/g)].map((m) => m[1]);
  for (const k of used) assert.ok(k in TEXT.en, `missing key ${k}`);
});

t('no network, no inline or foreign script', () => {
  assert.match(html, /Content-Security-Policy[^>]*connect-src 'none'/);
  assert.match(html, /script-src 'self'/);
  const scripts = [...html.matchAll(/<script([^>]*)>([\s\S]*?)<\/script>/g)];
  assert.equal(scripts.length, 1);
  assert.match(scripts[0][1], /src="product\.js"/);
  assert.equal(scripts[0][2].trim(), '');
  const js = fs.readFileSync(new URL('../../web/product.js', import.meta.url), 'utf8');
  for (const banned of ['fetch(', 'XMLHttpRequest', 'sendBeacon', 'WebSocket', 'innerHTML', 'eval(']) {
    assert.ok(!js.includes(banned), banned);
  }
});

t('entry links only open the app itself, relative to the page', () => {
  const hrefs = [...html.matchAll(/href="([^"]+)"/g)].map((m) => m[1]);
  for (const h of hrefs) {
    assert.ok(h === './#/auth' || h === 'https://github.com/fdittgen-png/deskilo', h);
  }
  for (const id of ['go-demo', 'go-signin', 'go-join']) {
    assert.match(html, new RegExp(`id="${id}" [^>]*href="\\./#/auth"`), id);
  }
});

t('a field: blank is unknown, a comma decimal is a number, text stays text', () => {
  assert.equal(fieldValue(''), null);
  assert.equal(fieldValue('  '), null);
  assert.equal(fieldValue('12,5'), 12.5);
  assert.equal(fieldValue('0'), 0);
  assert.equal(fieldValue('-3'), '-3');
  assert.equal(fieldValue('1e3'), '1e3');
});

t('the form, filled in, plans what was worked out by hand', () => {
  const fields = {
    currency: 'eur', setup_hours: '6', hourly_value: '40',             // setup 240.00
    backend_plan: '25', storage_used: '12', storage_free: '8', storage_price: '0,125', // 25 + 4 x 0.125 = 25.50
    backup: '0', pay_count: '40', pay_average: '60', pay_percent: '1.5', pay_fixed: '0.25', // 46.00
    admin_hours: '2',                                                    // 80.00
    assistant_funding: 'user', assistant_tokens: '5000000', assistant_price: '3', // not applicable
  };
  const plan = planCost(scenarioFromFields(fields));
  assert.equal(plan.currency, 'EUR');
  assert.equal(plan.one_time.known_minor, 24000);
  assert.equal(plan.recurring.known_minor, 2550 + 4600 + 8000);
  assert.ok(plan.one_time.complete && plan.recurring.complete);
  const en = describePlan(plan, 'en');
  assert.equal(en[0], 'One-time setup: €240.00');
  assert.equal(en[1], 'Each month: €151.50');
  const fr = describePlan(plan, 'fr');
  assert.match(fr[1], /^Chaque mois\u202f: 151,50\s€$/);
});

t('a blank field makes the month "at least", naming what is missing', () => {
  const plan = planCost(scenarioFromFields({ currency: 'EUR', backend_plan: '25', storage_free: '8', storage_used: '1', storage_price: '1', backup: '', pay_count: '0', pay_average: '0', pay_percent: '0', pay_fixed: '0', admin_hours: '0', hourly_value: '0', setup_hours: '0', assistant_funding: 'user' }));
  const lines = describePlan(plan, 'en');
  assert.equal(lines[1], 'Each month: €25.00 (at least — some values are still unknown)');
  assert.ok(lines.includes('  Not counted: Backup and monitoring — left blank'));
});

t('a funded assistant is billed per started million tokens', () => {
  const plan = planCost(scenarioFromFields({ currency: 'EUR', assistant_funding: 'deskilo', assistant_tokens: '2500000', assistant_price: '3', backend_plan: '0', storage_free: '0', storage_used: '0', storage_price: '0', backup: '0', pay_count: '0', pay_average: '0', pay_percent: '0', pay_fixed: '0', admin_hours: '0', hourly_value: '0', setup_hours: '0' }));
  assert.equal(plan.recurring.known_minor, 900);
});

t('an invalid currency says so instead of a number', () => {
  assert.deepEqual(describePlan({ currency: '' }, 'de'), [TEXT.de.resultInvalidCurrency]);
});

t('every capability the evidence lists has a name in every language', () => {
  assert.ok(CAPABILITIES.length > 0);
  for (const l of LOCALES) {
    for (const c of CAPABILITIES) assert.ok(TEXT[l][capabilityKey(c.id)], `${l}: ${c.id}`);
  }
  const named = Object.keys(TEXT.en).filter((k) => k.startsWith('cap_'));
  assert.deepEqual(named.sort(), CAPABILITIES.map((c) => capabilityKey(c.id)).sort(),
    'no label for a capability the evidence no longer lists');
});

t('planned, unevidenced or unknown is never shown as available', () => {
  assert.equal(capabilityState({ status: 'roadmap', evidence: ['unit:gated'] }), 'planned');
  assert.equal(capabilityState({ status: 'shipped', evidence: [] }), 'unknown');
  assert.equal(capabilityState({ status: 'beta', evidence: ['unit:gated'] }), 'unknown');
  assert.equal(capabilityState({ status: 'shipped', evidence: ['unit:gated'] }), 'tested');
  assert.equal(capabilityState({ status: 'shipped', evidence: ['unit:gated', 'named_runtime:recorded'] }), 'verified');
  for (const l of LOCALES) {
    for (const r of capabilityRows(l)) {
      const c = CAPABILITIES.find((x) => x.id === r.id);
      if (c.status !== 'shipped') {
        assert.notEqual(r.text, TEXT[l].capStateTested, `${l}: ${r.id}`);
        assert.notEqual(r.text, TEXT[l].capStateVerified, `${l}: ${r.id}`);
      }
    }
  }
  assert.ok(capabilityRows('en').some((r) => r.id === 'mcp.write' && r.state === 'planned'));
});

console.log(`product page: ${cases} cases passed`);

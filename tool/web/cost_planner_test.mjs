// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1635 E2 — hand-calculated fixtures for web/cost_planner.js. Every
// expected number below was worked out on paper, not produced by the
// planner, and each case varies one thing.
import assert from 'node:assert/strict';
import { planCost, parseScenario, serializeScenario, SCENARIO_VERSION } from '../../web/cost_planner.js';

let cases = 0;
const t = (name, fn) => { fn(); cases++; };
const base = (components, extra = {}) => ({ version: 1, currency: 'EUR', components, ...extra });

t('zero is zero, blank is unknown', () => {
  const r = planCost(base([
    { id: 'a', kind: 'recurring', type: 'flat', amount: 0 },
    { id: 'b', kind: 'recurring', type: 'flat', amount: null },
  ]));
  assert.equal(r.recurring.known_minor, 0);
  assert.equal(r.recurring.complete, false);
  assert.deepEqual(r.recurring.unresolved.map((u) => [u.id, u.reason]), [['b', 'unknown']]);
});

t('setup and operation stay apart', () => {
  const r = planCost(base([
    { id: 'setup', kind: 'one_time', type: 'hours', hours: 6.5, hourly_value: 40 },   // 260.00
    { id: 'plan', kind: 'recurring', type: 'flat', amount: 25 },                       // 25.00
  ]));
  assert.equal(r.one_time.known_minor, 26000);
  assert.equal(r.recurring.known_minor, 2500);
  assert.ok(r.one_time.complete && r.recurring.complete);
});

t('usage inside the allowance costs nothing; beyond it is billed per increment, rounded up', () => {
  // 250 GB used, 250 GB free -> 0; 251 GB -> 1 GB over, billed per 1 GB at 0.125.
  const inside = planCost(base([{ id: 'eg', kind: 'recurring', type: 'usage', usage: 250, increment: 1, price_per_increment: 0.125, allowance_group: 'egress' }], { allowances: { egress: 250 } }));
  assert.equal(inside.recurring.known_minor, 0);
  // 8.2 GB over at 10 GB packages of 2.50 -> 1 package -> 2.50
  const pack = planCost(base([{ id: 'st', kind: 'recurring', type: 'usage', usage: 108.2, increment: 10, price_per_increment: 2.5, allowance_group: 's' }], { allowances: { s: 100 } }));
  assert.equal(pack.recurring.known_minor, 250);
});

t('a shared allowance is counted once across components', () => {
  // group 'fn' gives 500 000 free; A uses 400 000 (free), B uses 300 000 ->
  // 100 000 free left, 200 000 billed per 1 000 000 at 2.00 -> 1 increment -> 2.00
  const r = planCost(base([
    { id: 'A', kind: 'recurring', type: 'usage', usage: 400000, increment: 1000000, price_per_increment: 2, allowance_group: 'fn' },
    { id: 'B', kind: 'recurring', type: 'usage', usage: 300000, increment: 1000000, price_per_increment: 2, allowance_group: 'fn' },
  ], { allowances: { fn: 500000 } }));
  assert.equal(r.recurring.known_minor, 200);
  assert.deepEqual(r.lines.map((l) => l.minor), [0, 200]);
});

t('an allowance group nobody entered is unknown, not free', () => {
  const r = planCost(base([{ id: 'x', kind: 'recurring', type: 'usage', usage: 10, increment: 1, price_per_increment: 1, allowance_group: 'nope' }]));
  assert.deepEqual(r.recurring.unresolved.map((u) => u.reason), ['unknown']);
});

t('payment fees: count x (value x percent + fixed)', () => {
  // 40 payments of 60.00 at 1.5% + 0.25 -> 40 x (0.90 + 0.25) = 46.00
  const r = planCost(base([{ id: 'pay', kind: 'recurring', type: 'payments', count: 40, average_value: 60, percent_fee: 1.5, fixed_fee: 0.25 }]));
  assert.equal(r.recurring.known_minor, 4600);
  const frac = planCost(base([{ id: 'pay', kind: 'recurring', type: 'payments', count: 2.5, average_value: 60, percent_fee: 1, fixed_fee: 0 }]));
  assert.deepEqual(frac.recurring.unresolved.map((u) => [u.reason, u.field]), [['invalid', 'count']]);
});

t('a member-supplied assistant costs this scenario nothing; a funded one is billed', () => {
  const user = planCost(base([{ id: 'ai', kind: 'recurring', type: 'assistant', funding: 'user', usage: 1e6, increment: 1e6, price_per_increment: 3 }]));
  assert.equal(user.recurring.known_minor, 0);
  assert.equal(user.lines[0].status, 'not_applicable');
  // 2.4 M tokens per 1 M at 3.00 -> 3 increments -> 9.00
  const funded = planCost(base([{ id: 'ai', kind: 'recurring', type: 'assistant', funding: 'deskilo', usage: 2.4e6, increment: 1e6, price_per_increment: 3 }]));
  assert.equal(funded.recurring.known_minor, 900);
});

t('NaN, Infinity, negatives, strings and absurd values are invalid, never coerced', () => {
  for (const bad of [NaN, Infinity, -1, '12', 1e13]) {
    const r = planCost(base([{ id: 'v', kind: 'recurring', type: 'flat', amount: bad }]));
    assert.deepEqual(r.recurring.unresolved.map((u) => u.reason), ['invalid'], String(bad));
    assert.equal(r.recurring.known_minor, 0);
  }
  const zeroInc = planCost(base([{ id: 'z', kind: 'recurring', type: 'usage', usage: 1, increment: 0, price_per_increment: 1 }]));
  assert.deepEqual(zeroInc.recurring.unresolved.map((u) => u.field), ['increment']);
});

t('another currency needs a rate, a date and a source', () => {
  const c = { id: 'usd', kind: 'recurring', type: 'flat', amount: 25, currency: 'USD' };
  const bare = planCost(base([c]));
  assert.deepEqual(bare.recurring.unresolved.map((u) => u.reason), ['mixed_currency']);
  const noSource = planCost(base([c], { conversions: [{ from: 'USD', rate: 0.92, date: '2026-09-27', source: '' }] }));
  assert.equal(noSource.ok, false);
  assert.equal(noSource.recurring.complete, false);
  // 25 USD x 0.92 = 23.00 EUR
  const ok = planCost(base([c], { conversions: [{ from: 'USD', rate: 0.92, date: '2026-09-27', source: 'ECB reference rate' }] }));
  assert.equal(ok.recurring.known_minor, 2300);
  assert.equal(ok.lines[0].provenance.source, 'ECB reference rate');
});

t('the scenario currency decides the grain', () => {
  const jpy = planCost({ version: 1, currency: 'JPY', components: [{ id: 'a', kind: 'recurring', type: 'hours', hours: 1.5, hourly_value: 1001 }] });
  assert.equal(jpy.recurring.known_minor, 1502); // 1501.5 -> 1502 yen
  const kwd = planCost({ version: 1, currency: 'KWD', components: [{ id: 'a', kind: 'recurring', type: 'flat', amount: 1.2345 }] });
  assert.equal(kwd.recurring.known_minor, 1235); // 1.235 dinar in fils (half away from zero)
});

t('an invalid currency or component is refused, not guessed', () => {
  assert.equal(planCost({ currency: 'euro', components: [] }).ok, false);
  const r = planCost(base([{ id: 'q', kind: 'monthly', type: 'flat', amount: 1 }]));
  assert.deepEqual(r.errors, ['component:q']);
});

t('saving and reading back: bounded, versioned, unknown fields dropped', () => {
  const s = base([{ id: 'a', kind: 'recurring', type: 'flat', amount: 3, onclick: 'alert(1)' }], { allowances: { egress: 250, 'bad key': 1 }, extra: 'x' });
  const text = serializeScenario(s);
  assert.equal(text, serializeScenario(JSON.parse(text)));
  const back = parseScenario(text);
  assert.equal(back.version, SCENARIO_VERSION);
  assert.ok(!('onclick' in back.components[0]));
  assert.ok(!('extra' in back));
  assert.deepEqual(Object.keys(back.allowances), ['egress']);
  assert.throws(() => parseScenario(JSON.stringify({ version: 2 })));
  assert.throws(() => parseScenario('x'.repeat(70000)));
  assert.throws(() => parseScenario('{not json'));
});

console.log(`cost planner: ${cases} cases passed`);

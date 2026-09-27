// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1635 E2 — the operating-cost and responsibility planner's arithmetic.
// Pure: no DOM, no network, no clock. The page feeds it a scenario the
// visitor typed; nothing here knows a price the visitor did not enter.
//
// The rules it keeps:
//  * blank (null) is UNKNOWN and deliberately entered 0 is ZERO: an
//    unknown component is listed as unresolved, never counted as free;
//  * a shared allowance (a free tier several components draw from) is
//    counted ONCE, consumed in the order the components are listed;
//  * each usage component is billed in its own increments, rounded up;
//  * one scenario currency; a component in another currency needs an
//    entered rate, date and source, or it stays unresolved;
//  * the total is a KNOWN SUBTOTAL plus the unresolved list — never a
//    complete-looking number while anything is unknown;
//  * one-time setup and recurring operation are separate;
//  * an assistant the member brings themselves costs this scenario
//    nothing; only a Deskilo-funded one applies token volumes and prices.

export const SCENARIO_VERSION = 1;
export const MAX_SCENARIO_BYTES = 64 * 1024;
const MAX_VALUE = 1e12;

const DIGITS = { JPY: 0, KRW: 0, ISK: 0, CLP: 0, KWD: 3, BHD: 3, OMR: 3, JOD: 3, TND: 3 };
export const minorDigits = (code) => DIGITS[code] ?? 2;

const TYPES = new Set(['flat', 'usage', 'hours', 'payments', 'assistant']);
const KINDS = new Set(['one_time', 'recurring']);

// A number the visitor entered, or null when the field was left blank.
// Anything else (NaN, Infinity, negative, absurdly large, a string) is
// invalid — reported, never coerced.
function num(v) {
  if (v === null || v === undefined || v === '') return { blank: true };
  if (typeof v !== 'number' || !Number.isFinite(v) || v < 0 || v > MAX_VALUE) {
    return { invalid: true };
  }
  return { value: v };
}

const isCode = (c) => typeof c === 'string' && /^[A-Z]{3}$/.test(c);

/// The cost of one component in its own currency (major units), or a
/// reason it has none: 'unknown' | 'invalid' | 'not_applicable'.
function componentCost(c, allowances) {
  const read = (...names) => {
    const out = {};
    for (const n of names) {
      const r = num(c[n]);
      if (r.invalid) return { reason: 'invalid', field: n };
      if (r.blank) return { reason: 'unknown', field: n };
      out[n] = r.value;
    }
    return { values: out };
  };
  switch (c.type) {
    case 'flat': {
      const r = read('amount');
      return r.values ? { cost: r.values.amount } : r;
    }
    case 'hours': {
      const r = read('hours', 'hourly_value');
      return r.values ? { cost: r.values.hours * r.values.hourly_value } : r;
    }
    case 'payments': {
      const r = read('count', 'average_value', 'percent_fee', 'fixed_fee');
      if (!r.values) return r;
      const v = r.values;
      if (!Number.isInteger(v.count)) return { reason: 'invalid', field: 'count' };
      return { cost: v.count * (v.average_value * v.percent_fee / 100 + v.fixed_fee) };
    }
    case 'assistant':
      if (c.funding === 'user') return { reason: 'not_applicable' };
      if (c.funding !== 'deskilo') return { reason: 'invalid', field: 'funding' };
    // falls through: a Deskilo-funded assistant is billed like usage.
    case 'usage': {
      const r = read('usage', 'increment', 'price_per_increment');
      if (!r.values) return r;
      const v = r.values;
      if (v.increment <= 0) return { reason: 'invalid', field: 'increment' };
      let usage = v.usage;
      if (c.allowance_group != null) {
        if (!(c.allowance_group in allowances)) {
          return { reason: 'unknown', field: 'allowance_group' };
        }
        const left = allowances[c.allowance_group];
        const used = Math.min(left, usage);
        allowances[c.allowance_group] = left - used;
        usage -= used;
      }
      return { cost: Math.max(0, Math.ceil(usage / v.increment - 1e-9)) * v.price_per_increment };
    }
    default:
      return { reason: 'invalid', field: 'type' };
  }
}

/// Plans [scenario]. Returns, per kind (one_time, recurring), the known
/// subtotal in integer minor units of the scenario currency, whether it
/// is complete, and the unresolved components with their reason.
export function planCost(scenario) {
  const errors = [];
  const currency = scenario?.currency;
  if (!isCode(currency)) {
    return { ok: false, errors: ['currency'] };
  }
  const scale = 10 ** minorDigits(currency);
  const allowances = {};
  for (const [k, v] of Object.entries(scenario.allowances ?? {})) {
    const r = num(v);
    if (r.value === undefined) errors.push(`allowance:${k}`);
    else allowances[k] = r.value;
  }
  const conversions = {};
  for (const c of scenario.conversions ?? []) {
    const rate = num(c?.rate);
    if (!isCode(c?.from) || rate.value === undefined || rate.value === 0 ||
        typeof c.date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(c.date) ||
        typeof c.source !== 'string' || c.source.trim() === '') {
      errors.push(`conversion:${c?.from ?? '?'}`);
      continue;
    }
    conversions[c.from] = { rate: rate.value, date: c.date, source: c.source.trim() };
  }
  const out = {
    one_time: { known_minor: 0, complete: true, unresolved: [] },
    recurring: { known_minor: 0, complete: true, unresolved: [] },
  };
  const lines = [];
  for (const c of scenario.components ?? []) {
    const kind = KINDS.has(c?.kind) ? c.kind : null;
    const id = typeof c?.id === 'string' ? c.id.slice(0, 64) : '?';
    if (!kind || !TYPES.has(c?.type)) {
      errors.push(`component:${id}`);
      continue;
    }
    const bucket = out[kind];
    const r = componentCost(c, allowances);
    if (r.reason === 'not_applicable') {
      lines.push({ id, kind, status: 'not_applicable' });
      continue;
    }
    if (r.reason) {
      bucket.complete = false;
      bucket.unresolved.push({ id, reason: r.reason, field: r.field });
      continue;
    }
    let cost = r.cost;
    let provenance;
    const from = c.currency ?? currency;
    if (from !== currency) {
      const conv = conversions[from];
      if (!conv) {
        bucket.complete = false;
        bucket.unresolved.push({ id, reason: 'mixed_currency', field: 'currency' });
        continue;
      }
      cost *= conv.rate;
      provenance = { from, ...conv };
    }
    const minor = Math.round(cost * scale);
    bucket.known_minor += minor;
    lines.push({ id, kind, status: 'known', minor, ...(provenance ? { provenance } : {}) });
  }
  return { ok: errors.length === 0, errors, currency, ...out, lines,
    excluded: ['taxes', 'provider_fees_not_entered', 'exchange_rate_changes'] };
}

/// A saved scenario, read back safely: bounded, versioned, and keeping
/// only the fields the planner knows. Throws on anything else.
export function parseScenario(text) {
  if (typeof text !== 'string' || text.length > MAX_SCENARIO_BYTES) {
    throw new Error('scenario too large');
  }
  const raw = JSON.parse(text);
  if (raw?.version !== SCENARIO_VERSION) throw new Error('scenario version');
  const keep = ['id', 'kind', 'type', 'currency', 'amount', 'hours', 'hourly_value',
    'count', 'average_value', 'percent_fee', 'fixed_fee', 'funding', 'usage',
    'increment', 'price_per_increment', 'allowance_group', 'label'];
  const pick = (o, names) => Object.fromEntries(
    names.filter((n) => Object.hasOwn(o ?? {}, n)).map((n) => [n, o[n]]));
  return {
    version: SCENARIO_VERSION,
    currency: raw.currency,
    allowances: pick(raw.allowances, Object.keys(raw.allowances ?? {})
      .filter((k) => /^[a-z][a-z0-9_]{0,31}$/.test(k))),
    conversions: (Array.isArray(raw.conversions) ? raw.conversions : [])
      .slice(0, 20).map((c) => pick(c, ['from', 'rate', 'date', 'source'])),
    components: (Array.isArray(raw.components) ? raw.components : [])
      .slice(0, 100).map((c) => pick(c, keep)),
  };
}

/// The scenario as saved: the same object gives the same bytes.
export const serializeScenario = (s) => JSON.stringify(parseScenario(JSON.stringify(s)), null, 2);

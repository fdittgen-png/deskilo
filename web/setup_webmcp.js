// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup questionnaire's WebMCP tools (W1 of epic #2500). They read the
// page's own state and handlers through `window.__setup` (defined at the end
// of setup.html): the parameters come from DEFAULTS and FEATURES, the
// dependencies from REQUIRES, the words from T(), the export from the page's
// own buildXml. No second parameter table lives here — a new answer is a row
// in setup.html's PARAM_META, which the same-PR rule already demands.
//
// Without a WebMCP-capable browser WebMcp.register does nothing and the page
// behaves exactly as before.
(function (win) {
  'use strict';
  var P = win.__setup;
  var M = win.WebMcp;
  if (!P || !M) return;
  var T = P.T;
  var FEAT = 'features.';

  var copy = function (v) { return JSON.parse(JSON.stringify(v === undefined ? null : v)); };
  var same = function (a, b) { return JSON.stringify(a) === JSON.stringify(b); };
  var featureKeys = function () { return P.FEATURES.map(function (f) { return f[0]; }); };
  var isFeature = function (key) { return key.indexOf(FEAT) === 0 && featureKeys().indexOf(key.slice(FEAT.length)) >= 0; };
  var metaOf = function (key) {
    for (var i = 0; i < P.PARAM_META.length; i++) if (P.PARAM_META[i][0] === key) return P.PARAM_META[i];
    return null;
  };
  var readPath = function (root, path) {
    var o = root;
    var p = path.split('.');
    for (var i = 0; i < p.length; i++) { if (o == null) return undefined; o = o[p[i]]; }
    return o;
  };

  // The process each switch is filed under on the page.
  function processOf(feature) {
    for (var i = 0; i < P.PROCESSES.length; i++) {
      var sps = P.PROCESSES[i].subprocesses;
      for (var j = 0; j < sps.length; j++) {
        if (sps[j].features.indexOf(feature) >= 0) return { process: P.PROCESSES[i].key, title: P.processTitle(P.PROCESSES[i].key) };
      }
    }
    return null;
  }

  var TYPES = { bool: 'boolean', enum: 'string', int: 'integer', num: 'number', text: 'string', time: 'string', date: 'string', color: 'string', days: 'array', dates: 'array' };

  // Every parameter, as the page defines it right now (language included).
  function parameters() {
    var out = [];
    featureKeys().forEach(function (k) {
      var parent = P.REQUIRES[k];
      var proc = processOf(k);
      out.push({
        key: FEAT + k, type: 'boolean', label: P.featureTitle(k), help: P.featureDesc(k),
        default: !!P.DEFAULTS.features[k], requires: parent ? FEAT + parent : null,
        group: proc ? proc.title : null,
      });
    });
    P.PARAM_META.forEach(function (m) {
      var opt = m[3];
      var p = {
        key: m[0], type: TYPES[m[2]], label: T(m[1]), default: copy(readPath(P.DEFAULTS, m[0])),
        requires: m[4] && m[4].needs ? FEAT + m[4].needs : null,
      };
      if (m[2] === 'enum') p.allowed = opt();
      if (m[2] === 'days') p.allowed = P.WD.slice();
      if (m[2] === 'int' || m[2] === 'num') { if (opt && opt.min !== undefined) p.min = opt.min; if (opt && opt.max !== undefined) p.max = opt.max; }
      if (m[2] === 'time') p.format = 'HH:MM';
      if (m[2] === 'date' || m[2] === 'dates') p.format = 'YYYY-MM-DD';
      if (m[2] === 'color') p.format = '#RRGGBB';
      if (m[4] && m[4].secret) p.secret = true;
      out.push(p);
    });
    return out;
  }

  function currentValue(p) {
    var v = isFeature(p.key) ? !!P.S.features[p.key.slice(FEAT.length)] : copy(readPath(P.S, p.key));
    return p.secret && v ? T('webmcpSecretSet') : v;
  }

  function collections() {
    var out = [];
    Object.keys(P.PARAM_EXCLUDED).forEach(function (k) {
      var why = P.PARAM_EXCLUDED[k];
      if (why === 'collection') {
        var v = P.S[k];
        out.push({ key: k, count: Array.isArray(v) ? v.length : Object.keys(v || {}).length });
      }
    });
    return out;
  }

  var bad = function (key, code, reason, allowed, extra) {
    return M.fail(code, T('webmcpErrInvalid', { key: key, reason: reason }), allowed, extra);
  };

  // The same rules the UI applies: a select takes only its options, a time
  // reads as HH:MM, the brand colour as #RRGGBB (setup.html's own check).
  function validate(key, m, value) {
    var kind = m[2];
    var opt = m[3];
    var str = function (v) { return typeof v === 'string'; };
    if (kind === 'bool') return typeof value === 'boolean' ? { value: value } : { error: bad(key, 'validation_error', T('webmcpReasonBool'), [true, false]) };
    if (kind === 'enum') {
      var allowed = opt();
      var s = value === null || value === undefined ? '' : String(value);
      return allowed.indexOf(s) >= 0 ? { value: s } : { error: bad(key, 'validation_error', T('webmcpReasonEnum'), allowed) };
    }
    if (kind === 'int' || kind === 'num') {
      var n = typeof value === 'number' ? value : (str(value) && value.trim() !== '' ? Number(value) : NaN);
      var o = opt || {};
      var okType = isFinite(n) && (kind === 'num' || Math.floor(n) === n);
      if (!okType) return { error: bad(key, 'validation_error', T(kind === 'int' ? 'webmcpReasonInt' : 'webmcpReasonNum'), undefined, { min: o.min, max: o.max }) };
      if ((o.min !== undefined && n < o.min) || (o.max !== undefined && n > o.max)) return { error: bad(key, 'validation_error', T('webmcpReasonRange', { min: o.min === undefined ? '-' : o.min, max: o.max === undefined ? '-' : o.max }), undefined, { min: o.min, max: o.max }) };
      return { value: typeof P.DEFAULTS === 'object' && typeof readPath(P.DEFAULTS, key) === 'number' ? n : String(value).trim() };
    }
    if (kind === 'days') {
      if (!Array.isArray(value) || value.some(function (d) { return P.WD.indexOf(String(d)) < 0; })) return { error: bad(key, 'validation_error', T('webmcpReasonDays'), P.WD.slice()) };
      return { value: P.WD.filter(function (d) { return value.map(String).indexOf(d) >= 0; }) };
    }
    if (kind === 'dates') {
      if (!Array.isArray(value) || value.some(function (d) { return !str(d) || !/^\d{4}-\d{2}-\d{2}$/.test(d); })) return { error: bad(key, 'validation_error', T('webmcpReasonDates')) };
      return { value: value.slice() };
    }
    if (!str(value)) return { error: bad(key, 'validation_error', T('webmcpReasonText')) };
    if (kind === 'time' && P.mins(value) == null) return { error: bad(key, 'validation_error', T('webmcpReasonTime')) };
    if (kind === 'date' && value !== '' && !/^\d{4}-\d{2}-\d{2}$/.test(value)) return { error: bad(key, 'validation_error', T('webmcpReasonDate')) };
    if (kind === 'color' && value.trim() !== '' && !/^#[0-9a-f]{6}$/i.test(value.trim())) return { error: bad(key, 'validation_error', T('webmcpReasonColor')) };
    return { value: value };
  }

  // Applies one answer through the page's own handlers; returns the error
  // or null. `check` false skips validation (used to restore defaults).
  function apply(key, value, check) {
    if (isFeature(key)) {
      var f = key.slice(FEAT.length);
      if (typeof value !== 'boolean') return bad(key, 'validation_error', T('webmcpReasonBool'), [true, false]);
      P.applyFeature(f, value);
      return null;
    }
    var m = metaOf(key);
    if (!m) {
      if (Object.prototype.hasOwnProperty.call(P.PARAM_EXCLUDED, key)) return M.fail('unsupported', T('webmcpErrCollection', { key: key }));
      return M.fail('not_found', T('webmcpErrUnknownKey', { key: key }), parameters().map(function (p) { return p.key; }));
    }
    if (check && m[4] && m[4].needs && !P.on(m[4].needs)) {
      return M.fail('requires_feature', T('webmcpErrNeeds', { key: key, feature: P.featureTitle(m[4].needs) }), undefined, { requires: FEAT + m[4].needs });
    }
    var r = check ? validate(key, m, value) : { value: value };
    if (r.error) return r.error;
    P.set(key, r.value);
    if (key === 'country') P.onCountry(r.value);
    return null;
  }

  function snapshotAnswers() {
    var out = {};
    parameters().forEach(function (p) {
      out[p.key] = isFeature(p.key) ? !!P.S.features[p.key.slice(FEAT.length)] : copy(readPath(P.S, p.key));
    });
    return out;
  }
  function changedSince(before, except) {
    var after = snapshotAnswers();
    var out = {};
    Object.keys(after).forEach(function (k) { if (except.indexOf(k) < 0 && !same(before[k], after[k])) out[k] = after[k]; });
    return out;
  }
  function blockers() {
    return P.findings().filter(function (x) { return x.lvl === 'err'; }).map(function (x) { return x.t; });
  }
  function restoreState(snap) {
    Object.keys(P.S).forEach(function (k) { delete P.S[k]; });
    Object.assign(P.S, JSON.parse(snap));
    P.save();
  }
  function ordered(answers) {
    var keys = Object.keys(answers);
    return keys.filter(isFeature).concat(keys.filter(function (k) { return !isFeature(k); }));
  }

  function setAnswers(answers) {
    if (!answers || typeof answers !== 'object' || Array.isArray(answers) || !Object.keys(answers).length) {
      return M.fail('validation_error', T('webmcpErrEmpty'));
    }
    var snap = JSON.stringify(P.S);
    var before = snapshotAnswers();
    var errors = [];
    var keys = ordered(answers);
    keys.forEach(function (k) {
      var e = apply(k, answers[k], true);
      if (e) errors.push({ key: k, error: e.error });
    });
    if (errors.length) {
      restoreState(snap);
      P.rerender();
      return M.fail('validation_error', T('webmcpErrAtomic', { n: errors.length }), undefined, { errors: errors });
    }
    P.rerender();
    var values = {};
    keys.forEach(function (k) { values[k] = snapshotAnswers()[k]; });
    return M.ok({ applied: values, also_changed: changedSince(before, keys), blocking_findings: blockers() });
  }

  function listParameters(input) {
    var q = typeof input.query === 'string' ? input.query.trim().toLowerCase() : '';
    var f = typeof input.feature === 'string' ? input.feature.replace(FEAT, '') : '';
    var list = parameters();
    if (f) {
      if (featureKeys().indexOf(f) < 0) return M.fail('not_found', T('webmcpErrUnknownKey', { key: f }), featureKeys());
      list = list.filter(function (p) { return p.key === FEAT + f || p.requires === FEAT + f; });
    }
    if (q) list = list.filter(function (p) { return (p.key + ' ' + p.label + ' ' + (p.help || '')).toLowerCase().indexOf(q) >= 0; });
    return M.ok({ language: P.LANG, parameters: list, collections: collections() });
  }

  function explain(input) {
    var key = input.key;
    var p = parameters().filter(function (x) { return x.key === key; })[0];
    if (!p) return M.fail('not_found', T('webmcpErrUnknownKey', { key: String(key) }), parameters().map(function (x) { return x.key; }));
    var out = copy(p);
    out.value = currentValue(p);
    if (isFeature(key)) {
      var f = key.slice(FEAT.length);
      out.enables = featureKeys().filter(function (k) { return P.REQUIRES[k] === f; }).map(function (k) { return FEAT + k; });
      var chain = [];
      var up = P.REQUIRES[f];
      while (up) { chain.push(FEAT + up); up = P.REQUIRES[up]; }
      out.requires_chain = chain;
      out.effective = P.on(f);
    }
    out.dependants = parameters().filter(function (x) { return x.requires === key; }).map(function (x) { return x.key; });
    return M.ok(out);
  }

  function diff() {
    var out = [];
    parameters().forEach(function (p) {
      var v = isFeature(p.key) ? !!P.S.features[p.key.slice(FEAT.length)] : copy(readPath(P.S, p.key));
      if (!same(v, p.default)) out.push({ key: p.key, label: p.label, value: p.secret && v ? T('webmcpSecretSet') : v, default: p.default });
    });
    return M.ok({ differences: out });
  }

  function exportConfiguration(input) {
    if (input.format !== undefined && input.format !== 'xml') return M.fail('validation_error', T('webmcpErrFormat'), ['xml']);
    var blocked = blockers();
    if (blocked.length) return M.fail('blocked', T('webmcpErrBlocked', { n: blocked.length }), undefined, { findings: blocked });
    var text = P.buildXml();
    if (text == null) return M.fail('blocked', T('webmcpErrBlocked', { n: 1 }));
    return M.ok({ format: 'xml', text: text });
  }

  function reset(input) {
    if (input.keys === undefined) {
      P.reset();
      return M.ok({ reset: 'all' });
    }
    if (!Array.isArray(input.keys) || !input.keys.length) return M.fail('validation_error', T('webmcpErrEmpty'));
    var known = parameters().map(function (p) { return p.key; });
    var unknown = input.keys.filter(function (k) { return known.indexOf(k) < 0; });
    if (unknown.length) return M.fail('not_found', T('webmcpErrUnknownKey', { key: unknown.join(', ') }), known);
    var defaults = {};
    parameters().forEach(function (p) { defaults[p.key] = p.default; });
    input.keys.forEach(function (k) { apply(k, copy(defaults[k]), false); });
    P.rerender();
    return M.ok({ reset: input.keys });
  }

  function seedRates() {
    if (!P.VAT_RATES[P.S.country]) return M.fail('not_found', T('webmcpErrNoRates', { country: P.S.country }));
    P.seedVatRates();
    P.rerender();
    return M.ok({ country: P.S.country, rates: copy(P.S.vatRates) });
  }

  var str = function (key) { return { type: 'string', description: T(key) }; };
  function tools() {
    var obj = function (props, req) { return { type: 'object', properties: props, required: req || [], additionalProperties: false }; };
    var ro = { readOnlyHint: true };
    return [
      { name: 'list_parameters', description: T('webmcpListParameters'), annotations: ro,
        inputSchema: obj({ feature: str('webmcpArgFeature'), query: str('webmcpArgQuery') }), execute: listParameters },
      { name: 'get_answers', description: T('webmcpGetAnswers'), annotations: ro, inputSchema: obj({}),
        execute: function () {
          var out = {};
          parameters().forEach(function (p) { out[p.key] = currentValue(p); });
          return M.ok({ language: P.LANG, answers: out, collections: collections(), blocking_findings: blockers() });
        } },
      { name: 'set_answer', description: T('webmcpSetAnswer'),
        inputSchema: obj({ key: str('webmcpArgKey'), value: { description: T('webmcpArgValue') } }, ['key', 'value']),
        execute: function (input) {
          var one = {};
          one[input.key] = input.value;
          var r = setAnswers(one);
          // One question, one refusal: the refusal itself, not a list of one.
          if (!r.ok && r.error.errors && r.error.errors.length === 1) return { ok: false, error: r.error.errors[0].error };
          return r;
        } },
      { name: 'set_answers', description: T('webmcpSetAnswers'),
        inputSchema: obj({ answers: { type: 'object', description: T('webmcpArgAnswers') } }, ['answers']),
        execute: function (input) { return setAnswers(input.answers); } },
      { name: 'explain_parameter', description: T('webmcpExplain'), annotations: ro,
        inputSchema: obj({ key: str('webmcpArgKey') }, ['key']), execute: explain },
      { name: 'diff_with_default', description: T('webmcpDiff'), annotations: ro, inputSchema: obj({}), execute: diff },
      { name: 'export_configuration', description: T('webmcpExport'), annotations: ro,
        inputSchema: obj({ format: { type: 'string', enum: ['xml'], description: T('webmcpArgFormat') } }), execute: exportConfiguration },
      { name: 'reset', description: T('webmcpReset'),
        inputSchema: obj({ keys: { type: 'array', items: { type: 'string' }, description: T('webmcpArgKeys') } }), execute: reset },
      { name: 'seed_vat_rates', description: T('webmcpSeedRates'), inputSchema: obj({}), execute: seedRates },
    ];
  }

  function registerAll() { return M.register(tools()); }
  P.hooks.push(registerAll);
  win.__setupWebmcp = { tools: tools, parameters: parameters, registerAll: registerAll };
  registerAll();
})(window);

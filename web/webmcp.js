// SPDX-License-Identifier: AGPL-3.0-or-later
//
// WebMcp — the one shared module every DesKilo page uses to offer tools to an
// in-browser agent through WebMCP (epic #2500). No dependencies, same origin.
//
// Spec: https://webmachinelearning.github.io/webmcp (Draft Community Group
// Report, 9 October 2026, read when this file was written). Facts used:
//   * `document.modelContext` (older text: `navigator.modelContext`) — both
//     are looked up, the document first;
//   * `registerTool({name, description, inputSchema, execute, annotations},
//     {signal})` — aborting the signal unregisters the tool; changing a
//     tool's name, description or schema means unregister, then register;
//   * `execute(input, {signal})` resolves to any value, which the browser
//     serialises to JSON for the agent.
// Progressive enhancement only: without a modelContext every call is a no-op
// and nothing throws into the page.
//
// Output convention of every tool: {ok:true, data} or
// {ok:false, error:{code, message, allowed?}}.
(function (root) {
  'use strict';

  var controllers = []; // one AbortController per registered tool
  var logged = false;

  function debugOnce(e) {
    if (logged) return;
    logged = true;
    try { console.debug('[WebMcp]', e && e.message ? e.message : e); } catch (x) { /* nothing to do */ }
  }

  function context() {
    try {
      if (typeof document !== 'undefined' && document && document.modelContext) return document.modelContext;
      if (typeof navigator !== 'undefined' && navigator && navigator.modelContext) return navigator.modelContext;
    } catch (e) { debugOnce(e); }
    return null;
  }

  function ok(data) { return { ok: true, data: data }; }
  function fail(code, message, allowed, extra) {
    var error = { code: code, message: message };
    if (allowed !== undefined) error.allowed = allowed;
    if (extra) for (var k in extra) error[k] = extra[k];
    return { ok: false, error: error };
  }

  // A tool body that throws answers with an error, never with an exception.
  function guarded(execute) {
    return function (input, options) {
      try {
        return Promise.resolve(execute(input || {}, options)).then(null, function (e) {
          debugOnce(e);
          return fail('internal_error', String(e && e.message ? e.message : e));
        });
      } catch (e) {
        debugOnce(e);
        return Promise.resolve(fail('internal_error', String(e && e.message ? e.message : e)));
      }
    };
  }

  function dispose() {
    var list = controllers;
    controllers = [];
    list.forEach(function (c) { try { c.abort(); } catch (e) { debugOnce(e); } });
  }

  // Replaces whatever this module registered before: the caller passes the
  // whole current list (a language change simply calls register again).
  function register(tools) {
    var mc = context();
    if (!mc || typeof mc.registerTool !== 'function') return { supported: false };
    dispose();
    var count = 0;
    (tools || []).forEach(function (t) {
      try {
        var controller = new AbortController();
        var def = {
          name: t.name,
          description: t.description,
          inputSchema: t.inputSchema,
          execute: guarded(t.execute),
        };
        if (t.annotations) def.annotations = t.annotations;
        var p = mc.registerTool(def, { signal: controller.signal });
        if (p && typeof p.then === 'function') p.then(null, debugOnce);
        controllers.push(controller);
        count++;
      } catch (e) { debugOnce(e); }
    });
    return { supported: true, registered: count };
  }

  root.WebMcp = { register: register, dispose: dispose, supported: function () { return !!context(); }, ok: ok, fail: fail };
  if (typeof module !== 'undefined' && module.exports) module.exports = root.WebMcp;
})(typeof window !== 'undefined' ? window : globalThis);

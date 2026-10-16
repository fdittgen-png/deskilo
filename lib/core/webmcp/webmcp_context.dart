// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2504 — the browser seam of WebMCP. Only a web build reaches
// `document.modelContext`; every other build gets the no-op stub, so nothing
// of WebMCP is offered (or even reachable) on mobile or desktop.
export 'webmcp_context_stub.dart'
    if (dart.library.js_interop) 'webmcp_context_web.dart';

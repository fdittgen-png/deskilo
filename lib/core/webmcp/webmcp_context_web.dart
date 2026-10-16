// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Web half of the WebMCP seam (#2504): `document.modelContext` (older text:
// `navigator.modelContext`), the same lookup as `web/webmcp.js`.
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'webmcp_context_base.dart';

/// The browser's own `modelContext`.
WebMcpContext browserWebMcpContext() => _BrowserWebMcpContext();

JSObject? _modelContext() {
  for (final host in <JSObject>[web.document, web.window.navigator]) {
    final value = host.getProperty<JSAny?>('modelContext'.toJS);
    if (value.isA<JSObject>()) {
      final context = value as JSObject;
      if (context.has('registerTool')) return context;
    }
  }
  return null;
}

class _BrowserWebMcpContext implements WebMcpContext {
  @override
  bool get available => _modelContext() != null;

  @override
  WebMcpRegistration register({
    required String name,
    required String description,
    required String inputSchemaJson,
    required Map<String, Object?> annotations,
    required WebMcpExecute execute,
  }) {
    final context = _modelContext();
    if (context == null) throw StateError('no modelContext');
    final controller = web.AbortController();
    final definition = JSObject()
      ..['name'] = name.toJS
      ..['description'] = description.toJS
      ..['inputSchema'] = (jsonDecode(inputSchemaJson) as Object?).jsify()
      ..['annotations'] = annotations.jsify()
      ..['execute'] = ((JSAny? input, [JSAny? _]) {
        final plain = input.dartify();
        final args = plain is Map
            ? {for (final e in plain.entries) '${e.key}': e.value}
            : <String, Object?>{};
        return execute(args).then((value) => value.jsify()).toJS;
      }).toJS;
    final options = JSObject()..['signal'] = controller.signal;
    context.callMethod<JSAny?>('registerTool'.toJS, definition, options);
    return _BrowserRegistration(controller);
  }
}

class _BrowserRegistration implements WebMcpRegistration {
  _BrowserRegistration(this._controller);
  final web.AbortController _controller;

  @override
  void unregister() => _controller.abort();
}

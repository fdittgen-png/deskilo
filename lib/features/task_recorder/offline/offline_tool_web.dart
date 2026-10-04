// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1886 — the browser side: register or remove web/task_tool_sw.js, and
// report only what the browser confirms (a registration that reached
// `ready`), never an assumed state.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../../../core/trace/trace_logger.dart';
import 'offline_tool.dart';

OfflineTool platformOfflineTool() => const _WebOfflineTool();

const _script = 'task_tool_sw.js';

class _WebOfflineTool implements OfflineTool {
  const _WebOfflineTool();

  web.ServiceWorkerContainer? get _container {
    try {
      final navigator = web.window.navigator;
      if (!(navigator as JSObject).has('serviceWorker')) return null;
      return navigator.serviceWorker;
    } catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'no service worker container',
        stackTrace: st,
      );
      return null;
    }
  }

  Future<web.ServiceWorkerRegistration?> _mine(
    web.ServiceWorkerContainer c,
  ) async {
    final all = (await c.getRegistrations().toDart).toDart;
    for (final r in all) {
      final url = r.active?.scriptURL ?? r.installing?.scriptURL ?? '';
      if (url.endsWith(_script)) return r;
    }
    return null;
  }

  @override
  Future<OfflineToolState> state() async {
    final c = _container;
    if (c == null) return OfflineToolState.unsupported;
    try {
      return await _mine(c) == null
          ? OfflineToolState.off
          : OfflineToolState.ready;
    } catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'offline state unknown',
        stackTrace: st,
      );
      return OfflineToolState.failed;
    }
  }

  @override
  Future<OfflineToolState> keep() async {
    final c = _container;
    if (c == null) return OfflineToolState.unsupported;
    try {
      await c.register(_script.toJS).toDart;
      await c.ready.toDart;
      return OfflineToolState.ready;
    } catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'offline copy refused',
        stackTrace: st,
      );
      return OfflineToolState.failed;
    }
  }

  @override
  Future<OfflineToolState> forget() async {
    final c = _container;
    if (c == null) return OfflineToolState.unsupported;
    try {
      final mine = await _mine(c);
      mine?.active?.postMessage('forget'.toJS);
      await mine?.unregister().toDart;
      return OfflineToolState.off;
    } catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'offline copy not removed',
        stackTrace: st,
      );
      return OfflineToolState.failed;
    }
  }
}

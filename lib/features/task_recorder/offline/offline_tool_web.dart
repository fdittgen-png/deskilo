// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1886 — the browser side: register or remove web/task_tool_sw.js, and
// report ready only after the worker verifies its complete asset snapshot.

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../../../core/trace/trace_logger.dart';
import 'offline_tool.dart';

OfflineTool platformOfflineTool() => const _WebOfflineTool();

const _script = 'task_tool_sw.js';
const _timeout = Duration(minutes: 3);
const _stateTimeout = Duration(seconds: 3);
const _activationPoll = Duration(milliseconds: 100);

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
      if (url == Uri.parse(web.document.baseURI).resolve(_script).toString()) return r;
    }
    return null;
  }

  Future<bool> _request(web.ServiceWorkerRegistration registration, String command) async {
    final worker = registration.installing ?? registration.waiting ?? registration.active;
    if (worker == null) return false;
    await (() async {
      while (worker.state != 'activated') {
        if (worker.state == 'redundant') throw StateError('offline worker replaced');
        await Future<void>.delayed(_activationPoll);
      }
    })().timeout(_timeout);
    final channel = web.MessageChannel();
    final answer = Completer<bool>();
    channel.port1.onmessage = ((web.MessageEvent event) {
      if (!answer.isCompleted) answer.complete(event.data.dartify() == true);
    }).toJS;
    try {
      worker.postMessage(command.toJS, [channel.port2].toJS);
      return await answer.future.timeout(command == 'state' ? _stateTimeout : _timeout);
    } finally {
      channel.port1.close();
      channel.port2.close();
    }
  }

  @override
  Future<OfflineToolState> state() async {
    final c = _container;
    if (c == null) return OfflineToolState.unsupported;
    try {
      final mine = await _mine(c);
      if (mine == null) return OfflineToolState.off;
      return await _request(mine, 'state')
          ? OfflineToolState.ready : OfflineToolState.failed;
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
      final mine = await c.register(_script.toJS).toDart;
      return await _request(mine, 'keep')
          ? OfflineToolState.ready : OfflineToolState.failed;
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
      if (mine != null) {
        if (!await _request(mine, 'forget')) return OfflineToolState.failed;
        if (!(await mine.unregister().toDart).toDart) return OfflineToolState.failed;
      }
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

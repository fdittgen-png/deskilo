// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';
import 'dart:async';
import 'dart:math';

import '../trace/trace_logger.dart';

import 'auth_secret_store.dart';
import 'federation_handoff.dart';
import 'installation_auth_storage.dart';

AuthCallbackGuard? bootAuthCallbackGuard;

enum AuthCallbackStatus { authenticated, refused, unavailable }

/// The running installation alone owns its callback. Starting a new flow
/// cancels the previous one for that installation; other origins are untouched.
/// PKCE remains entirely owned by the pinned Supabase SDK.
class AuthCallbackGuard {
  AuthCallbackGuard(
    this.store,
    this.origin,
    this.callback, {
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final AuthSecretStore store;
  final Uri origin;
  final Uri callback;
  final DateTime Function() now;
  final feedback = StreamController<AuthCallbackStatus>.broadcast();
  AuthCallbackStatus? lastFeedback;

  /// #1648 — the same answers, tagged with the flow they belong to, so a
  /// screen never shows flow A's result on flow B.
  final events = StreamController<FederationEvent>.broadcast();
  FederationEvent? lastEvent;

  void report(AuthCallbackStatus status, {FederationFailure? failure}) {
    lastFeedback = status;
    feedback.add(status);
    final current = flow;
    if (current == null) return;
    _emit(status == AuthCallbackStatus.authenticated
        ? FederationEvent.authenticated(current)
        : FederationEvent.failed(current, failure ??
            (status == AuthCallbackStatus.unavailable
                ? FederationFailure.network
                : FederationFailure.refused)));
  }

  void _emit(FederationEvent event) {
    lastEvent = event;
    events.add(event);
  }

  /// Whether [pendingFlow] is still waiting for its browser return: begun,
  /// unclaimed and inside its window. Inspecting never relaunches anything.
  bool awaiting(String pendingFlow) =>
      flow == pendingFlow &&
      !_consumed &&
      (_pending!['expires'] as int) > now().millisecondsSinceEpoch;

  Map<String, dynamic>? _pending;
  bool _consumed = false;
  bool get consumed => _pending != null && _consumed;
  String? get flow => _pending?['flow'] as String?;
  Future<void> _tail = Future.value();
  Future<T> _ordered<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    // trace-exempt: callers receive the original error, without secret logs.
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  String get _key => installationAuthNamespace(origin, 'native.callback');
  String? get purpose => _pending?['purpose'] as String?;
  String? get expectedAccount => _pending?['account'] as String?;
  String? get issuer => _pending?['issuer'] as String?;
  String? get installationId => _pending?['installation'] as String?;

  Future<void> restore() async {
    final value = await store.read(_key);
    if (value == null) return;
    try {
      final parsed = jsonDecode(value);
      if (parsed is Map<String, dynamic> &&
          parsed['flow'] is String &&
          parsed['purpose'] is String &&
          parsed['expires'] is int &&
          (parsed['account'] == null || parsed['account'] is String) &&
          (parsed['expires'] as int) > now().millisecondsSinceEpoch &&
          (parsed['issuer'] == null || parsed['issuer'] is String) &&
          (parsed['installation'] == null ||
              parsed['installation'] is String)) {
        _pending = parsed;
      }
    } catch (error, stack) {
      // trace-exempt: corrupt secret metadata is discarded without logging it.
      TraceLogger.instance.warn(
        'auth',
        'invalid callback metadata',
        stackTrace: stack,
      );
    }
    if (_pending == null) await store.delete(_key);
  }

  Future<String> begin(
    String purpose, {
    String? account,
    String? issuer,
    String? installationId,
  }) => _ordered(() async {
    final random = Random.secure();
    final flow = base64Url.encode(
      List.generate(24, (_) => random.nextInt(256)),
    );
    final pending = <String, dynamic>{
      'flow': flow,
      'purpose': purpose,
      'account': account,
      'issuer': issuer,
      'installation': installationId,
      'expires': now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
    };
    await store.write(_key, jsonEncode(pending));
    _pending = pending;
    _consumed = false;
    lastFeedback = null;
    lastEvent = null;
    return callback
        .replace(
          queryParameters: {
            'deskilo_origin': installationAuthNamespace(origin, 'native'),
            'deskilo_flow': flow,
          },
        )
        .toString();
  });

  /// Synchronous because this is the SDK's documented callback predicate.
  /// It claims the URI once, before any exchange or session mutation occurs.
  bool claim(Uri uri, {String? account}) {
    final pending = _pending;
    if (_consumed ||
        pending == null ||
        account != expectedAccount ||
        (pending['expires'] as int) <= now().millisecondsSinceEpoch ||
        uri.scheme != callback.scheme ||
        uri.host != callback.host ||
        uri.port != callback.port ||
        uri.path != callback.path ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      return false;
    }
    final values = uri.queryParametersAll;
    if (values.values.any((v) => v.length != 1) ||
        values.containsKey('access_token') ||
        values.containsKey('refresh_token') ||
        uri.queryParameters['deskilo_origin'] !=
            installationAuthNamespace(origin, 'native') ||
        uri.queryParameters['deskilo_flow'] != pending['flow'] ||
        !(values.containsKey('code') || values.containsKey('error'))) {
      return false;
    }
    _consumed = true;
    _emit(FederationEvent.completing(pending['flow'] as String));
    return true;
  }

  Future<void> finish(String? completedFlow) => _ordered(() async {
    if (flow != completedFlow) return;
    _pending = null;
    _consumed = true;
    await store.delete(_key);
  });
}

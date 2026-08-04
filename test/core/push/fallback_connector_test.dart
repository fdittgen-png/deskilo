// SPDX-License-Identifier: 0BSD
//
// FCM-first with UnifiedPush fallback (#426): the first connector whose
// initialize succeeds owns the pipeline; the committed firebase_options
// stub makes FirebasePushConnector report unavailable, so today the
// fallback engages — and the day the owner configures Firebase, nothing
// else changes.

import 'dart:typed_data';

import 'package:deskilo/core/push/firebase_push_connector.dart';
import 'package:deskilo/core/push/push_connector.dart';
import 'package:flutter_test/flutter_test.dart';

class _Stub implements PushConnector {
  _Stub(this.available);
  final bool available;
  bool initialized = false;
  bool registered = false;

  @override
  Future<bool> initialize({
    required void Function(String url) onNewEndpoint,
    required void Function() onUnregistered,
    required void Function(Uint8List content) onMessage,
  }) async {
    initialized = true;
    return available;
  }

  @override
  Future<bool> hasDistributor() async => true;

  @override
  Future<void> register() async => registered = true;
}

void main() {
  test('the first available connector wins; later ones are not tried',
      () async {
    final first = _Stub(true);
    final second = _Stub(true);
    final fallback = FallbackPushConnector([first, second]);
    expect(
      await fallback.initialize(
          onNewEndpoint: (_) {}, onUnregistered: () {}, onMessage: (_) {}),
      isTrue,
    );
    await fallback.register();
    expect(first.registered, isTrue);
    expect(second.initialized, isFalse);
  });

  test('unavailable connectors are skipped in order', () async {
    final first = _Stub(false);
    final second = _Stub(true);
    final fallback = FallbackPushConnector([first, second]);
    expect(
      await fallback.initialize(
          onNewEndpoint: (_) {}, onUnregistered: () {}, onMessage: (_) {}),
      isTrue,
    );
    await fallback.register();
    expect(second.registered, isTrue);
  });

  test('nothing available → pipeline reports unavailable', () async {
    final fallback = FallbackPushConnector([_Stub(false)]);
    expect(
      await fallback.initialize(
          onNewEndpoint: (_) {}, onUnregistered: () {}, onMessage: (_) {}),
      isFalse,
    );
    expect(await fallback.hasDistributor(), isFalse);
  });

  test('the committed stub keeps Firebase OFF — the fallback engages '
      'by construction', () async {
    // FirebasePushConnector with the stub options returns false without
    // touching any platform channel (provable under flutter_test).
    final firebase = FirebasePushConnector();
    expect(
      await firebase.initialize(
          onNewEndpoint: (_) {}, onUnregistered: () {}, onMessage: (_) {}),
      isFalse,
    );
  });
}

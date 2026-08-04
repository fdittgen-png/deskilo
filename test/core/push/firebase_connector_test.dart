// SPDX-License-Identifier: 0BSD
//
// FCM is the sole transport (#428 — the F-Droid-era UnifiedPush
// fallback is gone). The committed firebase_options stub keeps
// Firebase OFF: initialize reports unavailable without touching any
// platform channel, so an unconfigured build stays local-only and
// Settings says why.

import 'package:deskilo/core/push/firebase_push_connector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the committed stub keeps Firebase OFF — provable under '
      'flutter_test', () async {
    final firebase = FirebasePushConnector();
    expect(
      await firebase.initialize(
          onNewEndpoint: (_) {}, onUnregistered: () {}, onMessage: (_) {}),
      isFalse,
    );
  });
}

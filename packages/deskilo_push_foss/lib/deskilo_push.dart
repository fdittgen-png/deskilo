// SPDX-License-Identifier: 0BSD
//
// deskilo_push — the F-DROID flavour (#716): no push transport.
//
// Same package name, same API as `packages/deskilo_push`, no Firebase
// and therefore no Google Play Services in the APK — the one thing
// F-Droid's scanner refuses. The app behaves exactly as an unconfigured
// store build does today: local notifications and the in-app inbox,
// and the Settings row says push is not available on this build.
export 'src/push_connector.dart';

import 'dart:typed_data';

import 'src/push_connector.dart';

/// Whether this build carries a push transport at all. False here.
const bool kPushTransportAvailable = false;

/// The transport this build ships with: none. [initialize] answers
/// false, which is the same signal an unconfigured Firebase gives, so
/// nothing downstream has a second code path.
PushConnector createPushConnector({PushWarn? onWarn}) => const _NoPush();

class _NoPush implements PushConnector {
  const _NoPush();

  @override
  Future<bool> initialize({
    required void Function(String url) onNewEndpoint,
    required void Function() onUnregistered,
    required void Function(Uint8List content) onMessage,
  }) async =>
      false;

  @override
  Future<void> register() async {}
}

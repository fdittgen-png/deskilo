// SPDX-License-Identifier: 0BSD
import 'dart:typed_data';

/// Thin transport seam so the app's PushService is testable (#72).
///
/// IDENTICAL in both `deskilo_push` packages (#716) — the store build
/// and the F-Droid build see the same API and differ only in what
/// [PushConnector.initialize] does behind it. A lint test pins the two
/// files byte-for-byte.
abstract class PushConnector {
  /// Wires the callbacks. Returns false when push is unavailable —
  /// unconfigured Firebase, unsupported platform, or a build with no
  /// push transport at all — and the caller must then skip [register].
  Future<bool> initialize({
    required void Function(String url) onNewEndpoint,
    required void Function() onUnregistered,
    required void Function(Uint8List content) onMessage,
  });

  Future<void> register();
}

/// What a connector reports when something goes wrong: the app hands
/// its own logger in, because a package cannot depend on the app.
typedef PushWarn = void Function(
  String message,
  Object error,
  StackTrace stackTrace,
);

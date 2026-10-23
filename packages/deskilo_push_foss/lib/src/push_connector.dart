// SPDX-License-Identifier: AGPL-3.0-or-later
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
  ///
  /// #2559 C2 — [onOpened] receives the data of a notification the person
  /// TAPPED (while the app ran in the background, or the tap that launched
  /// it) with the transport's message id when it has one. The data is an
  /// opaque reference the app resolves itself; it is never shown.
  Future<bool> initialize({
    required void Function(String url) onNewEndpoint,
    required void Function() onUnregistered,
    required void Function(Uint8List content) onMessage,
    void Function(Map<String, String> data, String? messageId)? onOpened,
  });

  /// Registers this device when notifications are allowed. #2559 C2 — the
  /// system prompt appears only when [ask] is true, i.e. after the person
  /// deliberately asked for notifications; a start never prompts. Answers
  /// whether notifications are allowed.
  Future<bool> register({bool ask = false});
}

/// What a connector reports when something goes wrong: the app hands
/// its own logger in, because a package cannot depend on the app.
typedef PushWarn = void Function(
  String message,
  Object error,
  StackTrace stackTrace,
);

// SPDX-License-Identifier: 0BSD
import 'package:flutter/foundation.dart';

/// Thin transport seam so [PushService] is testable (#72). FCM is the
/// only production transport since ADR 0011; the UnifiedPush connector
/// left with the rest of the F-Droid support (#428).
abstract class PushConnector {
  /// Wires the callbacks. Returns false when push is unavailable —
  /// unconfigured Firebase, unsupported platform — and the caller must
  /// then skip [register].
  Future<bool> initialize({
    required void Function(String url) onNewEndpoint,
    required void Function() onUnregistered,
    required void Function(Uint8List content) onMessage,
  });

  Future<void> register();
}

// SPDX-License-Identifier: MIT
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../trace/trace_logger.dart';

part 'nfc_uid_reader.g.dart';

/// Reads RFID/NFC tag UIDs for the kiosk badge flow (0046).
///
/// The UID is normalized to the badge credential contract shared with
/// `register_nfc_badge`: lowercase hex, no separators. Android-only —
/// iPads have no NFC hardware and iPhone kiosks would need the CoreNFC
/// entitlement, so every other platform reads as unavailable and the UI
/// simply hides the tap path.
class NfcUidReader {
  /// Whether a tap can be read here and now (Android + NFC enabled).
  Future<bool> isAvailable() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      return await NfcManager.instance.checkAvailability() ==
          NfcAvailability.enabled;
    } catch (e, st) {
      debugPrint('nfc availability check failed: $e\n$st');
      TraceLogger.instance
          .error('nfc', 'availability check failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Starts a read session; [onUid] fires with the normalized UID of the
  /// first tag presented. The caller stops the session (or it dies with
  /// the next [startRead]).
  Future<void> startRead({required ValueChanged<String> onUid}) async {
    await NfcManager.instance.startSession(
      pollingOptions: const {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
      },
      onDiscovered: (tag) {
        final id = NfcTagAndroid.from(tag)?.id;
        if (id == null || id.isEmpty) return;
        onUid(normalizeUid(id));
      },
    );
  }

  Future<void> stop() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (e, st) {
      // trace-exempt: stopping an already-stopped session is benign.
      debugPrint('nfc stop ignored: $e\n$st');
    }
  }

  /// The badge credential of a raw tag UID: lowercase hex, no separators
  /// (mirrored by `register_nfc_badge`'s server-side normalization).
  static String normalizeUid(Uint8List id) =>
      id.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Injectable seam so widget tests drive taps without NFC hardware.
@Riverpod(keepAlive: true)
NfcUidReader nfcUidReader(Ref ref) => NfcUidReader();

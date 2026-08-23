// SPDX-License-Identifier: 0BSD
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../trace/trace_logger.dart';
import 'web_nfc_stub.dart' if (dart.library.js_interop) 'web_nfc_web.dart';

part 'nfc_uid_reader.g.dart';

/// Reads RFID/NFC tag UIDs for the kiosk badge flow (0046).
///
/// The UID is normalized to the badge credential contract shared with
/// `register_nfc_badge`: lowercase hex, no separators. Android-native
/// via nfc_manager; on the WEB (#604) Chromium-on-Android's NDEFReader
/// covers the owner-side tag-configuration forms. iPads have no NFC
/// hardware and iPhone kiosks would need the CoreNFC entitlement, so
/// every other platform reads as unavailable and the UI simply hides
/// the tap path.
/// The precise NFC state of THIS device — the kiosk sheet shows it so a
/// silent tap path is diagnosable at the wall (field report: "the RFID
/// was not read" with no way to tell whether the pad lacks hardware, has
/// NFC toggled off in Android settings, or the session failed).
enum NfcStatus {
  /// Adapter present and enabled — a session can read taps.
  ready,

  /// Adapter present but turned OFF in the device's Android settings.
  off,

  /// No NFC here: non-Android platform or no adapter hardware.
  unsupported,
}

class NfcUidReader {
  /// The device's NFC state, resolved fresh on every call.
  Future<NfcStatus> status() async {
    if (kIsWeb) {
      // #604: NDEFReader exists only in Chromium on Android; whether
      // the adapter is ON is unknowable before scan(), so supported
      // means ready and a refused scan reports through startRead.
      return webNfcSupported() ? NfcStatus.ready : NfcStatus.unsupported;
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      return NfcStatus.unsupported;
    }
    try {
      return switch (await NfcManager.instance.checkAvailability()) {
        NfcAvailability.enabled => NfcStatus.ready,
        NfcAvailability.disabled => NfcStatus.off,
        _ => NfcStatus.unsupported,
      };
    } catch (e, st) {
      debugPrint('nfc availability check failed: $e\n$st');
      TraceLogger.instance
          .error('nfc', 'availability check failed', error: e, stackTrace: st);
      return NfcStatus.unsupported;
    }
  }

  /// Whether a tap can be read here and now (Android + NFC enabled).
  Future<bool> isAvailable() async => await status() == NfcStatus.ready;

  /// Starts a read session; [onUid] fires with the normalized UID of the
  /// first tag presented. The caller stops the session (or it dies with
  /// the next [startRead]).
  ///
  /// Kiosk hardening: the badge sheet opens repeatedly on a long-lived
  /// wall tablet, so a previous sheet's unawaited [stop] may still be in
  /// flight — stop first ourselves, and never let a failed startSession
  /// die silently (it used to leave the sheet showing the tap icon with
  /// a dead reader): trace it and retry once. Returns whether a read
  /// session is actually up, so the UI can say so.
  Future<bool> startRead({required ValueChanged<String> onUid}) async {
    if (kIsWeb) return webNfcStartRead(onUid);
    await stop();
    try {
      await _startSession(onUid);
      return true;
    } catch (e, st) {
      debugPrint('nfc start failed, retrying: $e\n$st');
      TraceLogger.instance
          .error('nfc', 'start failed, retrying', error: e, stackTrace: st);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      try {
        await _startSession(onUid);
        return true;
      } catch (e, st) {
        debugPrint('nfc start retry failed: $e\n$st');
        TraceLogger.instance
            .error('nfc', 'start retry failed', error: e, stackTrace: st);
        return false;
      }
    }
  }

  Future<void> _startSession(ValueChanged<String> onUid) =>
      NfcManager.instance.startSession(
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

  Future<void> stop() async {
    if (kIsWeb) return webNfcStop();
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

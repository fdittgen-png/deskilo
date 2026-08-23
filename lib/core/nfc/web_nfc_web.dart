// SPDX-License-Identifier: 0BSD
//
// Web NFC (#604): Chrome/Edge on ANDROID expose NDEFReader over HTTPS —
// the one browser family that can read an RFID/NFC tag, which is enough
// for the owner-side tag CONFIGURATION forms (seat tags, badge cards)
// in the web app. scan() must run from a user gesture (our read buttons
// are exactly that) and prompts for the NFC permission on first use.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

import '../trace/trace_logger.dart';

@JS('window')
external JSObject get _window;

extension type _NDEFReader._(JSObject _) implements JSObject {
  external factory _NDEFReader();
  external JSPromise<JSAny?> scan(_ScanOptions options);
  external set onreading(JSFunction handler);
}

extension type _ScanOptions._(JSObject _) implements JSObject {
  external factory _ScanOptions({JSAny signal});
}

extension type _AbortController._(JSObject _) implements JSObject {
  external factory _AbortController();
  external JSAny get signal;
  external void abort();
}

extension type _NDEFReadingEvent._(JSObject _) implements JSObject {
  external String get serialNumber;
}

_AbortController? _controller;

/// Whether this browser exposes Web NFC at all (feature detection —
/// desktop Chrome and every non-Chromium browser say no).
bool webNfcSupported() => _window.has('NDEFReader');

/// Starts a scan; [onUid] fires with the tag's serial number normalized
/// to the shared lowercase-hex-no-separator contract. Returns whether
/// the scan actually started (permission denied / NFC off report false
/// so the UI can say so instead of showing a dead reader).
Future<bool> webNfcStartRead(void Function(String uid) onUid) async {
  await webNfcStop();
  try {
    final controller = _AbortController();
    _controller = controller;
    final reader = _NDEFReader();
    reader.onreading = ((JSObject event) {
      final serial = _NDEFReadingEvent._(event).serialNumber;
      final uid = serial.toLowerCase().replaceAll(RegExp('[^0-9a-f]'), '');
      if (uid.isNotEmpty) onUid(uid);
    }).toJS;
    await reader.scan(_ScanOptions(signal: controller.signal)).toDart;
    return true;
  } catch (e, st) {
    debugPrint('web nfc scan failed: $e\n$st');
    TraceLogger.instance
        .error('nfc', 'web scan failed', error: e, stackTrace: st);
    return false;
  }
}

Future<void> webNfcStop() async {
  _controller?.abort();
  _controller = null;
}

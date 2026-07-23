// SPDX-License-Identifier: 0BSD
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'front_camera.dart';

part 'qr_scan_widget.g.dart';

/// Builds an embedded camera QR scanner delivering decoded payloads to
/// [onCode]. Injectable seam (the camera cannot run in widget tests —
/// the NfcUidReader idiom): production embeds flutter_zxing's
/// [ReaderWidget] (libre, GMS-free, ADR 0003 — the scan-to-join
/// decoder); tests inject a fake that emits codes on demand.
typedef QrScanWidgetBuilder = Widget Function({
  required ValueChanged<String> onCode,
});

/// Whether this device can host the embedded camera scanner (the kiosk
/// tablet path — mobile only; desktop kiosks keep wedge scanners).
/// defaultTargetPlatform, not dart:io — widget tests run as android.
bool get qrScanSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

@Riverpod(keepAlive: true)
QrScanWidgetBuilder qrScanWidgetBuilder(Ref ref) {
  // Front camera by default: a wall tablet's back lens faces the wall,
  // so badges are presented to the screen side. Device preference in
  // Settings flips to the back camera for handheld use.
  final front = ref.watch(frontCameraScanProvider).value ?? true;
  return ({required onCode}) => ReaderWidget(
        showFlashlight: false,
        showGallery: false,
        showToggleCamera: false,
        lensDirection: front
            ? CameraLensDirection.front
            : CameraLensDirection.back,
        onScan: (result) {
          final text = result.text ?? '';
          if (text.isNotEmpty) onCode(text);
        },
      );
}

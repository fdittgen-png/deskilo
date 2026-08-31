// SPDX-License-Identifier: 0BSD
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';


part 'qr_scan_widget.g.dart';

/// Builds an embedded camera QR scanner delivering decoded payloads to
/// [onCode]. Injectable seam (the camera cannot run in widget tests —
/// the NfcUidReader idiom): production embeds flutter_zxing's
/// [ReaderWidget] (libre, GMS-free, ADR 0003 — the scan-to-join
/// decoder); tests inject a fake that emits codes on demand.
typedef QrScanWidgetBuilder = Widget Function({
  required ValueChanged<String> onCode,
  bool front,
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
  // #773 — the LENS is the CALLER's decision: ScanCameraBox resolves the
  // stored preference against its surface's own default (kiosks front,
  // handheld scans back) and passes the result down. The builder used to
  // re-read the provider with `?? true`, silently re-defaulting every
  // fresh install to the front camera — the invite QR then faced the
  // joiner instead of the code.
  return ({required onCode, bool front = true}) => ReaderWidget(
        showFlashlight: false,
        showGallery: false,
        showToggleCamera: false,
        // Our scan boxes clip the preview — the default crop overlay
        // would mark a region that isn't where decoding happens.
        showScannerOverlay: false,
        // Decode the FULL frame (field report: the card's QR was
        // clearly visible in the preview but sat outside the default
        // CENTRED 50% crop square, so nothing ever decoded). 0 is the
        // library's own no-crop path (multi-scan uses it).
        cropPercent: 0,
        // Printed cards get scanned at an angle, on glossy paper, in
        // kiosk lighting — the harder/inverted passes read them.
        tryHarder: true,
        tryInverted: true,
        // Every DesKilo code is a QR (badges, space cards, join codes):
        // restricting the format keeps full-frame decoding fast.
        codeFormat: Format.qrCode,
        lensDirection: front
            ? CameraLensDirection.front
            : CameraLensDirection.back,
        onScan: (result) {
          final text = result.text ?? '';
          if (text.isNotEmpty) onCode(text);
        },
      );
}

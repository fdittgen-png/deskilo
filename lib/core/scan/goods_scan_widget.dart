// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4360 (G11) -- the embedded camera reader of the goods sheets: the same free-software `flutter_zxing` reader the
// QR scanners use, asked for product and place codes (EAN-13, EAN-8, UPC-A/E, Code 128, DataMatrix, QR). An
// injectable seam like the QR one (the camera cannot run in widget tests): tests inject a fake that emits codes.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import 'goods_code_formats.dart';

/// Builds the camera reader: every decoded text goes to [onCode]; a camera that could not start (a refused
/// permission, no camera) is reported to [onError].
typedef GoodsScanWidgetBuilder = Widget Function({
  required ValueChanged<String> onCode,
  required bool front,
  ValueChanged<Object>? onError,
});

final goodsScanWidgetBuilderProvider = Provider<GoodsScanWidgetBuilder>(
  (ref) => ({required onCode, required front, onError}) => ReaderWidget(
    showFlashlight: false,
    showGallery: false,
    showToggleCamera: false,
    showScannerOverlay: false,
    // the whole frame is decoded: a label is not always in the middle
    cropPercent: 0,
    tryHarder: true,
    tryInverted: true,
    codeFormat: goodsCodeFormats,
    lensDirection: front ? CameraLensDirection.front : CameraLensDirection.back,
    onControllerCreated: (controller, error) {
      if (error != null) onError?.call(error);
    },
    onScan: (result) {
      final text = result.text ?? '';
      if (text.isNotEmpty) onCode(text);
    },
  ),
);

// SPDX-License-Identifier: 0BSD
//
// The production QR scanner's decode parameters (#564): the field
// report was a card QR clearly visible in the preview that never
// decoded — flutter_zxing's default decodes only a CENTRED 50% crop
// square, with the harder/inverted passes off. The camera cannot run
// in tests; building the widget (without pumping) pins the parameters
// structurally.
import 'package:deskilo/core/scan/qr_scan_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

void main() {
  test('the scanner decodes the FULL frame, tries harder/inverted, and '
      'restricts to QR', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final builder = container.read(qrScanWidgetBuilderProvider);
    final widget = builder(onCode: (_) {}) as ReaderWidget;

    expect(widget.cropPercent, 0);
    expect(widget.tryHarder, isTrue);
    expect(widget.tryInverted, isTrue);
    expect(widget.tryRotate, isTrue);
    expect(widget.codeFormat, Format.qrCode);
    // The crop overlay would mark a region that is not where decoding
    // happens inside our clipped scan boxes.
    expect(widget.showScannerOverlay, isFalse);
    expect(widget.lensDirection, CameraLensDirection.front);
  });
}

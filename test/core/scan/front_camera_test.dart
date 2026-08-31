// SPDX-License-Identifier: 0BSD
//
// Front-camera scanning (field request): a wall-mounted kiosk tablet has
// its back lens against the wall, so badge QR codes are read with the
// FRONT (screen-side) camera by default; a Settings switch flips to the
// back camera for handheld devices.
import 'package:deskilo/core/scan/front_camera.dart';
import 'package:deskilo/core/scan/qr_scan_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import '../../helpers/mock_providers.dart';

void main() {
  test(
      'the scanner uses the front camera by default; the preference '
      'flips it to the back lens', () async {
    final container = ProviderContainer(
      overrides: [
        frontCameraStoreProvider
            .overrideWithValue(InMemoryFrontCameraStore()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(frontCameraScanProvider.future);

    // #773 — the LENS is the caller's argument now: ScanCameraBox
    // resolves the stored preference against its surface default and
    // passes the result down; the builder's own default stays front.
    ReaderWidget build({bool? front}) =>
        container.read(qrScanWidgetBuilderProvider)(
          onCode: (_) {},
          front: front ?? true,
        ) as ReaderWidget;

    expect(build().lensDirection, CameraLensDirection.front);
    expect(build(front: false).lensDirection, CameraLensDirection.back);
  });

  test('the preference persists through the store — and "never chosen" '
      'stays visible as null (#773)', () async {
    final store = InMemoryFrontCameraStore();
    final container = ProviderContainer(
      overrides: [frontCameraStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    expect(await container.read(frontCameraScanProvider.future), isNull);
    await container.read(frontCameraScanProvider.notifier).setEnabled(false);
    expect(store.value, isFalse);
  });
}

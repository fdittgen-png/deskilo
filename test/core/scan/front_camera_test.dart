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

    ReaderWidget build() => container.read(qrScanWidgetBuilderProvider)(
          onCode: (_) {},
        ) as ReaderWidget;

    expect(build().lensDirection, CameraLensDirection.front);

    await container.read(frontCameraScanProvider.notifier).setEnabled(false);
    expect(build().lensDirection, CameraLensDirection.back);
  });

  test('the preference persists through the store', () async {
    final store = InMemoryFrontCameraStore();
    final container = ProviderContainer(
      overrides: [frontCameraStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    expect(await container.read(frontCameraScanProvider.future), isTrue);
    await container.read(frontCameraScanProvider.notifier).setEnabled(false);
    expect(store.value, isFalse);
  });
}

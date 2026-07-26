// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_radius.dart';
import 'front_camera.dart';
import 'qr_scan_widget.dart';

/// The shared camera embed of the scan sheets (kiosk badge, space QR):
/// the injectable scanner plus a FLIP button (field request) that
/// switches between the front and back lens on the spot. The flip
/// writes the same device preference as Settings, so the choice sticks.
class ScanCameraBox extends ConsumerWidget {
  const ScanCameraBox({
    super.key,
    required this.cameraKey,
    required this.onCode,
  });

  /// The pinned test/find key of the camera area (each sheet keeps its
  /// historical key).
  final Key cameraKey;
  final ValueChanged<String> onCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Watched: flipping rebuilds the scanner with the other lens.
    final builder = ref.watch(qrScanWidgetBuilderProvider);
    final front = ref.watch(frontCameraScanProvider).value ?? true;
    return ClipRRect(
      borderRadius: AppRadius.mdAll,
      child: SizedBox(
        key: cameraKey,
        height: 220,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Keyed on the lens: the camera controller must fully
            // remount to open the other camera.
            KeyedSubtree(
              key: ValueKey('scan-camera-$front'),
              child: builder(onCode: onCode),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filledTonal(
                key: const ValueKey('scan-flip-camera'),
                tooltip: l10n?.settingsFrontCamera ??
                    'Scan with the front camera',
                icon: const Icon(Icons.flip_camera_android_outlined),
                onPressed: () => ref
                    .read(frontCameraScanProvider.notifier)
                    .setEnabled(!front),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

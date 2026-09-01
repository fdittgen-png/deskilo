// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_radius.dart';
import '../trace/act_trace.dart';
import 'front_camera.dart';
import 'qr_scan_widget.dart';

/// The shared camera embed of the scan sheets (kiosk badge, space QR):
/// the injectable scanner plus a FLIP button (field request) that
/// switches between the front and back lens on the spot. The flip
/// writes the same device preference as Settings, so the choice sticks.
class ScanCameraBox extends ConsumerStatefulWidget {
  const ScanCameraBox({
    super.key,
    required this.cameraKey,
    required this.onCode,
    this.defaultFront = true,
  });

  /// Which lens to open while NO preference is stored (#773): the kiosk
  /// keeps the historical front default (a wall tablet's back lens faces
  /// the wall), but a HANDHELD scan — joining by invite QR, scanning a
  /// seat card — must open the back camera, or a fresh install streams
  /// the joiner's face and "never identifies the barcode". An explicit
  /// stored preference always wins; the flip button covers exceptions.

  /// The pinned test/find key of the camera area (each sheet keeps its
  /// historical key).
  final Key cameraKey;
  final ValueChanged<String> onCode;
  final bool defaultFront;

  @override
  ConsumerState<ScanCameraBox> createState() => _ScanCameraBoxState();
}

class _ScanCameraBoxState extends ConsumerState<ScanCameraBox> {
  /// The lens the trace last reported, so a rebuild does not repeat it.
  bool? _tracedLens;

  /// #791 — which lens actually opened, once per change.
  ///
  /// "The scanner does not recognise the barcode" has two very different
  /// causes: a camera pointed at the wrong thing (the front-lens default
  /// of #773) and a code that decodes but is refused downstream. The
  /// first is invisible without this line — nothing else in the trace
  /// says a camera ever started, let alone which one.
  void _traceLens(bool front) {
    if (_tracedLens == front) return;
    _tracedLens = front;
    ActTrace.scan.step('camera-open', {
      'lens': front ? 'front' : 'back',
      'surface': widget.cameraKey.toString(),
      'default': widget.defaultFront ? 'front' : 'back',
    });
  }

  void _onCode(String payload) {
    ActTrace.scan.step('decoded', {
      'shape': ActTrace.payloadShape(payload),
      'surface': widget.cameraKey.toString(),
    });
    widget.onCode(payload);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Watched: flipping rebuilds the scanner with the other lens.
    final builder = ref.watch(qrScanWidgetBuilderProvider);
    final lens = ref.watch(frontCameraScanProvider);

    // #662 — WAIT for the stored lens before mounting the camera.
    //
    // The preference is read asynchronously, so on the first open of an
    // app session `.value` is null and the old code fell back to `true`.
    // With the back camera stored, the sequence was:
    //
    //   frame 1  loading  → front=true  → key 'scan-camera-true'
    //                                   → camera starts initialising
    //   prefs resolve     → front=false → key 'scan-camera-false'
    //                                   → subtree DESTROYED and remounted
    //                                     on top of a half-initialised
    //                                     controller
    //
    // The preview came up but decoding never started, so the first scan
    // of a session silently did nothing; closing and reopening worked
    // because the keepAlive provider already held the value and the
    // camera mounted once, with the right lens. Reported for the space
    // scan sheet AND the kiosk, which is expected — both embed this box.
    //
    // Mounting only once the answer is known costs a frame or two of
    // placeholder and makes the camera's lifecycle single-shot.
    if (!lens.hasValue && !lens.hasError) {
      return ClipRRect(
        borderRadius: AppRadius.mdAll,
        child: SizedBox(
          key: widget.cameraKey,
          height: 220,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    // An unreadable preference falls back to the surface's own default —
    // and still mounts ONCE.
    final front = lens.value ?? widget.defaultFront;
    _traceLens(front);
    return ClipRRect(
      borderRadius: AppRadius.mdAll,
      child: SizedBox(
        key: widget.cameraKey,
        height: 220,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Keyed on the lens: the camera controller must fully
            // remount to open the other camera.
            KeyedSubtree(
              key: ValueKey('scan-camera-$front'),
              child: builder(onCode: _onCode, front: front),
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

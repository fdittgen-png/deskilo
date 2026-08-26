// SPDX-License-Identifier: 0BSD
//
// #662 — the first scan of an app session silently did nothing.
//
// The lens preference is read asynchronously. ScanCameraBox fell back to
// `true` while it loaded and keyed the camera subtree on that value, so
// with the BACK camera stored the sequence was:
//
//   frame 1  loading  → front=true  → key 'scan-camera-true'
//                                   → camera starts initialising
//   resolve           → front=false → key 'scan-camera-false'
//                                   → subtree destroyed and REMOUNTED on
//                                     a half-initialised controller
//
// The preview appeared but decoding never began. Closing and reopening
// worked, because the keepAlive provider already held the value and the
// camera mounted once. Reported against the space-scan sheet AND the
// kiosk — both embed this box, so both had it.
//
// The camera must mount EXACTLY ONCE, and only once the lens is known.
import 'dart:async';

import 'package:deskilo/core/scan/front_camera.dart';
import 'package:deskilo/core/scan/qr_scan_widget.dart';
import 'package:deskilo/core/scan/scan_camera_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

/// Counts how many times the scanner widget is CREATED, and how many
/// distinct element instances existed — a remount shows up as a second
/// initState, which is the whole bug.
class _CountingScanner extends StatefulWidget {
  const _CountingScanner({required this.mounts});

  final List<int> mounts;

  @override
  State<_CountingScanner> createState() => _CountingScannerState();
}

class _CountingScannerState extends State<_CountingScanner> {
  @override
  void initState() {
    super.initState();
    widget.mounts.add(1);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// A store whose read is held open until the test releases it, so the
/// loading frame is observable rather than a race.
class _SlowFrontCameraStore implements FrontCameraStore {
  _SlowFrontCameraStore(this.value);

  final bool value;
  final completer = Completer<bool>();

  @override
  Future<bool> read() => completer.future;

  @override
  Future<void> write(bool enabled) async {}

  void resolve() => completer.complete(value);
}

Future<void> _pumpBox(
  WidgetTester tester, {
  required FrontCameraStore store,
  required List<int> mounts,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        frontCameraStoreProvider.overrideWithValue(store),
        qrScanWidgetBuilderProvider.overrideWithValue(
          ({required onCode}) => _CountingScanner(mounts: mounts),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ScanCameraBox(
            cameraKey: const ValueKey('camera'),
            onCode: (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('the camera mounts ONCE, after the stored lens resolves — '
      'back camera', (tester) async {
    final store = _SlowFrontCameraStore(false); // back lens stored
    final mounts = <int>[];
    await _pumpBox(tester, store: store, mounts: mounts);

    // While the preference is loading nothing may claim the camera: a
    // controller started now is the one that gets torn down.
    expect(mounts, isEmpty,
        reason: 'the camera must not start before the lens is known');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    store.resolve();
    await tester.pumpAndSettle();

    expect(mounts.length, 1,
        reason: 'exactly one mount — a second means the subtree was '
            'remounted mid-initialisation, which is the bug');
  });

  testWidgets('the camera mounts ONCE when the stored lens matches the '
      'old fallback — front camera', (tester) async {
    // This case never reproduced the bug (true == the old fallback, so
    // the key never changed), which is why it only bit people who had
    // flipped to the back lens. Pinned so the fix does not regress it.
    final store = _SlowFrontCameraStore(true);
    final mounts = <int>[];
    await _pumpBox(tester, store: store, mounts: mounts);

    expect(mounts, isEmpty);
    store.resolve();
    await tester.pumpAndSettle();
    expect(mounts.length, 1);
  });

  testWidgets('flipping the lens deliberately DOES remount — the camera '
      'has to reopen on the other hardware', (tester) async {
    final mounts = <int>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          frontCameraStoreProvider
              .overrideWithValue(InMemoryFrontCameraStore()),
          qrScanWidgetBuilderProvider.overrideWithValue(
            ({required onCode}) => _CountingScanner(mounts: mounts),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ScanCameraBox(
              cameraKey: const ValueKey('camera'),
              onCode: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(mounts.length, 1);

    await tester.tap(find.byKey(const ValueKey('scan-flip-camera')));
    await tester.pumpAndSettle();

    expect(mounts.length, 2,
        reason: 'the flip button must reopen the other camera — this '
            'remount is intentional, unlike the one the fix removes');
  });
}

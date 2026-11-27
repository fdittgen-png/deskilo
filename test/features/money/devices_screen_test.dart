// SPDX-License-Identifier: AGPL-3.0-or-later
// #4466 — Settings › Devices on a phone and on a desk: a board's readable code typed is read and the board shown (its
// id, model and fingerprint, and that connecting it comes later); a typo is refused in words under the field and the
// refusal goes when the code is changed; where there is no camera the page says so and typing still works; a board's
// QR scanned shows the board with its whole fingerprint; a board already connected is listed in place of "none".
import 'package:deskilo/core/demo/data/demo_till_board.dart';
import 'package:deskilo/core/demo/data/stores.dart';
import 'package:deskilo/core/scan/front_camera.dart';
import 'package:deskilo/core/scan/qr_scan_widget.dart';
import 'package:deskilo/features/money/presentation/screens/devices_screen.dart';
import 'package:deskilo/features/money/providers/till_board_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final _l10n = AppLocalizationsEn();
const _qr = demoTillBoardQr;

Future<void> _type(WidgetTester tester, String code) async {
  final field = find.descendant(of: find.byKey(const ValueKey('device-pairing-code')), matching: find.byType(EditableText));
  await tester.enterText(field, code);
  await tester.pump();
  await tester.ensureVisible(find.byKey(const ValueKey('device-pairing-check')));
  await tester.tap(find.byKey(const ValueKey('device-pairing-check')));
  await tester.pump();
}

void main() {
  for (final (name, size) in [('phone', const Size(390, 844)), ('desk', const Size(1440, 900))]) {
    group('on a $name', () {
      testWidgets("the board's typed code shows the board; a typo is refused in words until the code is changed", (tester) async {
        await pumpApp(tester, const DevicesScreen(cameraAvailable: false), size: size);
        await tester.pump();
        expect(find.text(_l10n.devicePairingNone), findsOneWidget);
        expect(find.byKey(const ValueKey('device-pairing-no-camera')), findsOneWidget, reason: 'no camera: said, and typing still works');

        await _type(tester, '3DNGP-UN9GC');
        expect(find.text(_l10n.devicePairingRefusedCheck), findsOneWidget, reason: 'two symbols swapped');
        expect(find.byKey(const ValueKey('device-pairing-found')), findsNothing);

        await tester.enterText(find.descendant(of: find.byKey(const ValueKey('device-pairing-code')), matching: find.byType(EditableText)), '3DNGP-UN9C');
        await tester.pump();
        expect(find.text(_l10n.devicePairingRefusedCheck), findsNothing, reason: 'the refusal goes once the code is changed');

        await _type(tester, '3dngp un9cg');
        expect(find.byKey(const ValueKey('device-pairing-found')), findsOneWidget);
        expect(find.text(_l10n.devicePairingBoard('11111111', 'ideaspark ST7789')), findsOneWidget);
        expect(find.text(_l10n.devicePairingFingerprint('AB')), findsOneWidget);
        expect(find.text(_l10n.devicePairingLater), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a code with a letter a board never shows, or too short, is refused for that', (tester) async {
        await pumpApp(tester, const DevicesScreen(cameraAvailable: false), size: size);
        await tester.pump();
        await _type(tester, '3DNGO-UN9CG');
        expect(find.text(_l10n.devicePairingRefusedAlphabet), findsOneWidget);
        await _type(tester, '3DNGP');
        expect(find.text(_l10n.devicePairingRefusedLength), findsOneWidget);
      });

      testWidgets('a board already connected is listed, and "none" is not said', (tester) async {
        await pumpApp(
          tester,
          const DevicesScreen(cameraAvailable: false),
          size: size,
          overrides: [connectedTillBoardsProvider.overrideWithValue(AsyncData([demoTillBoard()]))],
        );
        await tester.pump();
        expect(find.byKey(const ValueKey('device-connected-11111111')), findsOneWidget);
        expect(find.text(_l10n.devicePairingBoard('11111111', 'ideaspark ST7789')), findsOneWidget);
        expect(find.byKey(const ValueKey('device-pairing-none')), findsNothing);
      });

      testWidgets("a board's QR scanned shows the board with its whole fingerprint", (tester) async {
        late ValueChanged<String> emit;
        await pumpApp(
          tester,
          const DevicesScreen(cameraAvailable: true),
          size: size,
          overrides: [
            frontCameraStoreProvider.overrideWithValue(InMemoryFrontCameraStore()),
            qrScanWidgetBuilderProvider.overrideWithValue(({required onCode, bool front = true}) {
              emit = onCode;
              return const SizedBox(key: ValueKey('fake-camera'));
            }),
          ],
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('fake-camera')), findsOneWidget);
        emit(_qr);
        await tester.pump();
        expect(find.text(_l10n.devicePairingBoard('11111111', 'ideaspark ST7789')), findsOneWidget);
        expect(find.text(_l10n.devicePairingFingerprint('AB12-CD34')), findsOneWidget);
      });
    });
  }
}

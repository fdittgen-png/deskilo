// SPDX-License-Identifier: AGPL-3.0-or-later
// #4466, #4454 — Settings › Devices on a phone and on a desk:
// - a board's readable code typed is read and the board shown; a typo is refused in words until the code is changed;
//   a typed code connects nothing (its QR is asked for);
// - where there is no camera the page says so and typing still works;
// - the business's boards are listed; the owner approves a waiting board after the fingerprint dialog and removes one;
//   someone else is offered neither;
// - a board's QR scanned shows the board; the owner picks a till and is given a code, valid once, and withdraws it;
//   a QR of an older firmware asks for the new firmware;
// - a refusal of the server is said in words.
import 'package:deskilo/core/demo/data/demo_till_board.dart';
import 'package:deskilo/core/demo/data/stores.dart';
import 'package:deskilo/core/devices/connected_boards_provider.dart';
import 'package:deskilo/core/devices/device_board.dart';
import 'package:deskilo/core/devices/device_code.dart';
import 'package:deskilo/core/scan/front_camera.dart';
import 'package:deskilo/core/scan/qr_scan_widget.dart';
import 'package:deskilo/features/money/domain/till_drawer.dart';
import 'package:deskilo/features/money/presentation/screens/devices_screen.dart';
import 'package:deskilo/features/money/providers/till_drawer_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final _l10n = AppLocalizationsEn();
const _qr = demoTillBoardQr;
final _olderQr = demoTillBoardQr.substring(0, demoTillBoardQr.indexOf('&h='));

/// The server as the page sees it: boards to list, the commands it was given, and a refusal to answer with.
class _Boards implements TillBoardPort {
  _Boards(this.list);

  final List<TillBoard> list;
  final calls = <String>[];
  TillBoardRefusal? refuse;

  Future<void> _maybeRefuse() async {
    if (refuse case final r?) throw TillBoardRefused(r);
  }

  @override
  Future<List<TillBoard>> boards(String workspaceId) async => list;

  @override
  Future<TillBoardCode> code(String workspaceId, String tillId, DeviceCode scanned) async {
    await _maybeRefuse();
    calls.add('code $tillId ${scanned.id} ${scanned.secretHash}');
    return TillBoardCode(id: 'c1', code: 'K7M2-9QXR-4TNB', expiresAt: DateTime.utc(2026, 11, 27, 18, 5));
  }

  @override
  Future<bool> cancelCode(String codeId) async {
    calls.add('cancel $codeId');
    return true;
  }

  @override
  Future<void> approve(String boardId, String fingerprint) async {
    await _maybeRefuse();
    calls.add('approve $boardId $fingerprint');
  }

  @override
  Future<bool> revoke(String boardId) async {
    calls.add('revoke $boardId');
    return true;
  }
}

const _waiting = TillBoard(
  id: 'b1',
  tillId: 't1',
  tillName: 'Front counter',
  deviceId: '22222222-2222-4222-8222-222222222222',
  profile: BoardProfile.e32r40t,
  fingerprint: 'CD34-EF56',
  firmware: '1.0.3',
  status: TillBoardStatus.pendingApproval,
);

Future<_Boards> _pump(
  WidgetTester tester,
  Size size, {
  bool owner = true,
  bool camera = false,
  List<TillBoard> boards = const [],
  ValueChanged<ValueChanged<String>>? onCamera,
}) async {
  final port = _Boards([...boards]);
  await pumpApp(
    tester,
    DevicesScreen(cameraAvailable: camera, workspaceId: 'ws-1', owner: owner),
    size: size,
    overrides: [
      tillBoardPortProvider.overrideWithValue(port),
      tillDrawerProvider('ws-1').overrideWith(
        (ref) async => const [
          DrawerTill(id: 't1', name: 'Front counter', active: true),
          DrawerTill(id: 't2', name: 'Old counter', active: false),
        ],
      ),
      if (camera) ...[
        frontCameraStoreProvider.overrideWithValue(InMemoryFrontCameraStore()),
        qrScanWidgetBuilderProvider.overrideWithValue(({required onCode, bool front = true}) {
          onCamera?.call(onCode);
          return const SizedBox(key: ValueKey('fake-camera'));
        }),
      ],
    ],
  );
  await tester.pumpAndSettle();
  return port;
}

Finder get _codeField =>
    find.descendant(of: find.byKey(const ValueKey('device-pairing-code')), matching: find.byType(EditableText));

Future<void> _type(WidgetTester tester, String code) async {
  await tester.enterText(_codeField, code);
  await tester.pump();
  await tester.ensureVisible(find.byKey(const ValueKey('device-pairing-check')));
  await tester.tap(find.byKey(const ValueKey('device-pairing-check')));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  for (final (name, size) in [('phone', const Size(390, 844)), ('desk', const Size(1440, 900))]) {
    group('on a $name', () {
      testWidgets("the board's typed code shows the board; a typo is refused in words until the code is changed", (tester) async {
        await _pump(tester, size);
        expect(find.text(_l10n.devicePairingNone), findsOneWidget);
        expect(find.byKey(const ValueKey('device-pairing-no-camera')), findsOneWidget, reason: 'no camera: said, and typing still works');

        await _type(tester, '3DNGP-UN9GC');
        expect(find.text(_l10n.devicePairingRefusedCheck), findsOneWidget, reason: 'two symbols swapped');
        expect(find.byKey(const ValueKey('device-pairing-found')), findsNothing);

        await tester.enterText(_codeField, '3DNGP-UN9C');
        await tester.pumpAndSettle();
        expect(find.text(_l10n.devicePairingRefusedCheck), findsNothing, reason: 'the refusal goes once the code is changed');

        await _type(tester, '3dngp un9cg');
        expect(find.byKey(const ValueKey('device-pairing-found')), findsOneWidget);
        expect(find.text(_l10n.devicePairingBoard('11111111', 'ideaspark ST7789')), findsOneWidget);
        expect(find.text(_l10n.devicePairingFingerprint('AB')), findsOneWidget);
        expect(find.byKey(const ValueKey('device-pairing-scan-to-connect')), findsOneWidget, reason: 'a typed code names no id');
        expect(find.byKey(const ValueKey('device-pairing-get-code')), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a code with a letter a board never shows, or too short, is refused for that', (tester) async {
        await _pump(tester, size);
        await _type(tester, '3DNGO-UN9CG');
        expect(find.text(_l10n.devicePairingRefusedAlphabet), findsOneWidget);
        await _type(tester, '3DNGP');
        expect(find.text(_l10n.devicePairingRefusedLength), findsOneWidget);
      });

      testWidgets("the business's boards are listed; the owner approves a waiting one after the fingerprint, and removes one",
          (tester) async {
        final port = await _pump(tester, size, boards: [_waiting]);
        expect(find.byKey(const ValueKey('device-pairing-none')), findsNothing);
        expect(find.text(_l10n.devicePairingBoard('22222222', 'LCDwiki E32R40T')), findsOneWidget);
        expect(find.text(_l10n.devicePairingTill('Front counter')), findsOneWidget);
        expect(find.text(_l10n.devicePairingStatusPending), findsOneWidget);

        await _tap(tester, const ValueKey('device-board-approve-22222222'));
        expect(find.text(_l10n.devicePairingApproveBody('CD34-EF56')), findsOneWidget, reason: 'the fingerprint to compare');
        await _tap(tester, const ValueKey('device-board-confirm'));
        expect(port.calls, ['approve b1 CD34-EF56']);

        await _tap(tester, const ValueKey('device-board-revoke-22222222'));
        expect(find.text(_l10n.devicePairingRevokeBody), findsOneWidget);
        await _tap(tester, const ValueKey('device-board-confirm'));
        expect(port.calls.last, 'revoke b1');
      });

      testWidgets("a refusal of the server is said in words", (tester) async {
        final port = await _pump(tester, size, boards: [_waiting]);
        port.refuse = TillBoardRefusal.notAllowed;
        await _tap(tester, const ValueKey('device-board-approve-22222222'));
        await _tap(tester, const ValueKey('device-board-confirm'));
        expect(find.text(_l10n.devicePairingNotOwner), findsOneWidget);
      });

      testWidgets('someone who is not the owner sees the boards and is offered no action', (tester) async {
        await _pump(tester, size, owner: false, boards: [_waiting]);
        expect(find.text(_l10n.devicePairingStatusPending), findsOneWidget);
        expect(find.byKey(const ValueKey('device-board-approve-22222222')), findsNothing);
        expect(find.byKey(const ValueKey('device-board-revoke-22222222')), findsNothing);
      });

      testWidgets("a board's QR scanned: the owner picks a till, is given a code once, and withdraws it", (tester) async {
        late ValueChanged<String> emit;
        final port = await _pump(tester, size, camera: true, onCamera: (e) => emit = e);
        emit(_qr);
        await tester.pumpAndSettle();
        expect(find.text(_l10n.devicePairingFingerprint('AB12-CD34')), findsOneWidget);
        final getCode = tester.widget<FilledButton>(find.byKey(const ValueKey('device-pairing-get-code')));
        expect(getCode.onPressed, isNull, reason: 'no code before a till is chosen');

        await _tap(tester, const ValueKey('device-pairing-till'));
        expect(find.text('Old counter'), findsNothing, reason: 'an inactive till takes no board');
        await tester.tap(find.text('Front counter').last);
        await tester.pumpAndSettle();
        await _tap(tester, const ValueKey('device-pairing-get-code'));
        expect(port.calls, ['code t1 11111111-1111-4111-8111-111111111111 ab12cd34${'0' * 56}']);
        expect(find.text(_l10n.devicePairingCode('K7M2-9QXR-4TNB')), findsOneWidget);

        await _tap(tester, const ValueKey('device-pairing-withdraw'));
        expect(port.calls.last, 'cancel c1');
        expect(find.byKey(const ValueKey('device-pairing-code-given')), findsNothing);
      });

      testWidgets("an older firmware's QR shows the board and asks for the new firmware", (tester) async {
        late ValueChanged<String> emit;
        await _pump(tester, size, camera: true, onCamera: (e) => emit = e);
        emit(_olderQr);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('device-pairing-needs-firmware')), findsOneWidget);
        expect(find.byKey(const ValueKey('device-pairing-get-code')), findsNothing);
      });
    });
  }
}

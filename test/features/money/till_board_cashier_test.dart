// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4517 -- a cashier authorizes a till board from the till drawer: a board that asks offers "Sell on this board as
// me"; afterwards it says until when the person sells on it and can be ended, and the board asks again; a refusal is
// said in words, and a board someone else sells on names them.
import 'package:deskilo/core/demo/data/demo_till_board.dart';
import 'package:deskilo/core/devices/connected_boards_provider.dart';
import 'package:deskilo/core/devices/device_board.dart';
import 'package:deskilo/features/money/presentation/screens/till_board_cashier.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();
final _now = DateTime.utc(2026, 11, 28, 9);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(WidgetTester tester, TillBoardPort port, Size size) async {
  await pumpApp(
    tester,
    const Scaffold(
      body: SingleChildScrollView(
        child: TillBoardCashierCard(workspaceId: 'ws-1'),
      ),
    ),
    size: size,
    overrides: [tillBoardPortProvider.overrideWithValue(port)],
  );
  await _settle(tester);
}

/// A board that refuses with [reason].
class _Refusing extends DemoTillBoards {
  _Refusing(this.reason) : super(now: () => _now);
  final TillBoardAuthorizeRefusal reason;

  @override
  Future<DateTime> authorize(String boardId) async =>
      throw TillBoardAuthorizeRefused(reason);
}

void main() {
  for (final (label, size) in const [
    ('phone', Size(390, 844)),
    ('desk', Size(1280, 900)),
  ]) {
    group('at a $label', () {
      testWidgets(
        'a board that asks is sold on as the person, then ended, and asks again',
        (tester) async {
          final boards = DemoTillBoards(now: () => _now)..seed();
          await _open(tester, boards, size);
          expect(find.text(_en.boardCashierAsks), findsOneWidget);
          final shortId = (await boards.cashierBoards('ws-1')).single.shortId;
          await tester.tap(find.byKey(ValueKey('board-cashier-sell-$shortId')));
          await _settle(tester);
          expect(
            find.textContaining(_en.boardCashierMine('').trim()),
            findsOneWidget,
          );
          expect(
            find.byKey(ValueKey('board-cashier-sell-$shortId')),
            findsNothing,
          );
          await tester.tap(find.byKey(ValueKey('board-cashier-end-$shortId')));
          await _settle(tester);
          expect(find.text(_en.boardCashierEnded), findsOneWidget);
          expect(
            find.byKey(ValueKey('board-cashier-sell-$shortId')),
            findsOneWidget,
            reason: 'the board asks again',
          );
        },
      );

      testWidgets('a refusal is said in words, and the board still asks', (
        tester,
      ) async {
        final boards = _Refusing(TillBoardAuthorizeRefusal.noRequest)..seed();
        await _open(tester, boards, size);
        final shortId = (await boards.cashierBoards('ws-1')).single.shortId;
        await tester.tap(find.byKey(ValueKey('board-cashier-sell-$shortId')));
        await _settle(tester);
        expect(find.text(_en.boardCashierRefusedNoRequest), findsOneWidget);
        expect(
          find.byKey(ValueKey('board-cashier-sell-$shortId')),
          findsOneWidget,
        );
      });
    });
  }

  test('every refusal has its own words', () {
    final said = {
      for (final r in TillBoardAuthorizeRefusal.values)
        boardAuthorizeFailureText(_en, TillBoardAuthorizeRefused(r)),
    };
    expect(said, hasLength(TillBoardAuthorizeRefusal.values.length));
  });

  test('the Demo answers as the server: an ended lease is nobody\'s, a board that does not ask is not authorized', () async {
    var now = _now;
    final boards = DemoTillBoards(now: () => now)..seed();
    final id = (await boards.cashierBoards('ws-1')).single.id;
    final until = await boards.authorize(id);
    expect(until, _now.add(const Duration(minutes: 30)));
    await expectLater(
      boards.authorize(id),
      throwsA(isA<TillBoardAuthorizeRefused>()),
    );
    now = until.add(const Duration(seconds: 1));
    expect((await boards.cashierBoards('ws-1')).single.lease, isNull);
  });
}

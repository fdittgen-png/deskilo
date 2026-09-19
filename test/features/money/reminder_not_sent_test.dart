// SPDX-License-Identifier: 0BSD
//
// #1532 — a reminder nobody received does not escalate anybody.
//
// `remindInvoice` recorded the dunning level and THEN opened the share
// sheet. The level is derived as `sent + 1`, so cancelling the sheet
// still moved the member up the ladder: the next attempt sent a level-2
// letter for a level-1 that never left the device. A dunning ladder is a
// legal instrument and its steps are supposed to have happened.
//
// The seam could not tell the difference either — `FileSharer` returned
// `void`, so a cancelled share looked exactly like a sent one. It
// reports the outcome now.
//
// `dismissed` is the unambiguous case and the one acted on here.
// `unknown` (share_plus `unavailable`: the platform shared but cannot
// say what the user did) is still recorded, deliberately — on a platform
// that always answers that way, refusing would mean a ladder that never
// advances at all. Which way that should go is the open question on the
// issue; the third test pins today's answer so changing it is a choice
// somebody makes rather than a side effect.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/share/file_sharer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

void main() {
  /// How many reminders the invoice carries after one tap of Send
  /// reminder, with the share sheet answering [outcome].
  Future<int> remindersAfter(
    WidgetTester tester,
    FileShareOutcome outcome,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final money = FakeMoneyRepository();
    final id = await money.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'member-1',
      period: kTestPeriod,
    );
    final at = money.invoices.indexWhere((x) => x.id == id);
    money.invoices[at] = money.invoices[at]
        .copyWith(issuedAt: kTestNow.subtract(const Duration(days: 20)));

    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          money: money,
          workspace: FakeWorkspaceRepository.withWorkspace(),
          fileSharer: ({
            required bytes,
            required fileName,
            required mimeType,
            String? text,
          }) async =>
              outcome,
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tapNavIcon(tester, Icons.account_balance_wallet_outlined);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('money-face-invoices')));
    await tester.pumpAndSettle();
    // The hub first, then the register — the same two steps the journey
    // test takes; the register is not the face's landing surface.
    await tester.ensureVisible(find.byKey(const ValueKey('invoices-button')));
    await tester.tap(find.byKey(const ValueKey('invoices-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
    await tester.pumpAndSettle();

    // The PDF build does real async work, like the journey test.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(ValueKey('invoice-remind-$id')));
      await tester.pumpAndSettle();
    });
    await tester.pumpAndSettle();
    return money.invoiceReminders[id]?.length ?? 0;
  }

  testWidgets('a cancelled share records nothing', (tester) async {
    expect(
      await remindersAfter(tester, FileShareOutcome.dismissed),
      0,
      reason: 'the member closed the sheet, so no letter exists — '
          'recording a level here is exactly what sent the next one at '
          'level 2 for a level 1 nobody received',
    );
  });

  testWidgets('a sent share records the level', (tester) async {
    expect(await remindersAfter(tester, FileShareOutcome.sent), 1);
  });

  testWidgets('an unreportable share records it too, for now',
      (tester) async {
    expect(
      await remindersAfter(tester, FileShareOutcome.unknown),
      1,
      reason: "today's answer to the open question on #1532: a platform "
          'that cannot say must not freeze the ladder. Pinned so that '
          'changing it is deliberate',
    );
  });
}

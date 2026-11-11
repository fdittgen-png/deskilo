// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-f -- the reminders shared by hand as a person meets them: grouped by
// level, one Share per line, a bottom bar that shares the next one, a level
// recorded only if the share left, a closed sheet that says so and keeps the
// line, and a result page of what was shared; no rule of the experience breaks
// at 320 and 390 px.
import 'dart:typed_data';

import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/share/file_sharer.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/application/reminder_queue.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/presentation/invoicing/reminder_queue_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';
import '../../ux/experience_guards.dart';

Finder _key(String k) => find.byKey(ValueKey(k));

/// The money fake whose record of a reminder can fail.
class _Repo extends FakeMoneyRepository {
  Exception? failRecord;

  @override
  Future<void> remindInvoice(String invoiceId) async {
    final failure = failRecord;
    if (failure != null) throw failure;
    return super.remindInvoice(invoiceId);
  }
}

void main() {
  late _Repo repo;
  var shares = 0;
  late List<String> ids;
  var outcome = FileShareOutcome.sent;
  final matched = <String>[];
  var holdingMoney = <String>{};
  final today = kTestNow;

  setUp(() async {
    repo = _Repo();
    shares = 0;
    outcome = FileShareOutcome.sent;
    matched.clear();
    holdingMoney = {};
    ids = [];
    for (final member in ['member-1', 'member-2']) {
      final id = await repo.createInvoice(
        workspaceId: 'ws-1',
        memberId: member,
        period: kTestPeriod,
      );
      final at = repo.invoices.indexWhere((x) => x.id == id);
      repo.invoices[at] = repo.invoices[at].copyWith(
        issuedAt: today.subtract(const Duration(days: 30)),
      );
      ids.add(id);
    }
  });

  ReminderQueue queue() => reminderQueueOf(
    [
      for (var i = 0; i < ids.length; i++)
        Receivable(
          invoiceId: ids[i],
          customerId: 'member-${i + 1}',
          customerName: i == 0 ? 'Anna Alder' : 'Ben Birk',
          number: 'INV-${i + 1}',
          currency: 'EUR',
          totalMinor: 12000,
          openMinor: 12000,
          issuedOn: today.subtract(const Duration(days: 30)),
          stage: ReceivableStage.open,
          dueOn: today.subtract(Duration(days: 10 + i)),
          reminderDueLevel: 1,
        ),
    ],
    today,
    ReminderMode.byHand,
    holdsUnassigned: holdingMoney,
  );

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    await pumpApp(
      tester,
      Consumer(
        builder: (context, ref, _) {
          ref.watch(authStateProvider);
          return ReminderQueueScreen(
            queue: queue(),
            today: today,
            onMatch: matched.add,
            previewOf: (line, invoice) async => (
              title: 'Reminder ${invoice.number}',
              report: const InvoiceReport(
                header: [ReportText('Dear customer')],
                body: [ReportText('Please pay invoice')],
                footer: [],
              ),
            ),
            letterOf: (line, invoice) async => (
              bytes: Uint8List.fromList([1]),
              fileName: 'reminder.pdf',
              message: 'Please pay',
            ),
          );
        },
      ),
      size: size,
      overrides: standardTestOverrides(
        money: repo,
        auth: FakeAuthRepository.signedIn(),
        workspace: FakeWorkspaceRepository.withWorkspace(),
        fileSharer: ({
          required bytes,
          required fileName,
          required mimeType,
          text,
        }) async {
          shares++;
          return outcome;
        },
      ),
    );
    // The ledger the screen reads: the archive must have answered.
    await tester.runAsync(() async {
      await tester.pumpAndSettle();
    });
    await tester.pumpAndSettle();
  }

  /// A share builds a PDF: real async work, as the old reminder test does.
  Future<void> tapReal(WidgetTester tester, Finder f) async {
    await tester.runAsync(() async {
      await tester.tap(f);
      await tester.pumpAndSettle();
    });
    await tester.pumpAndSettle();
  }

  testWidgets('lines are grouped by level, most late first, and the bar names '
      'the next customer', (tester) async {
    await pump(tester);
    expect(find.text('REMINDER 1'), findsOneWidget);
    expect(find.text('Anna Alder'), findsOneWidget);
    expect(find.text('Ben Birk'), findsOneWidget);
    expect(find.textContaining('10 days late'), findsOneWidget);
    expect(
      find.text('Share the next one · Ben Birk'),
      findsOneWidget,
      reason: 'Ben is 11 days late',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a share that left records one level and the bar moves on', (
    tester,
  ) async {
    await pump(tester);
    await tapReal(tester, _key('reminder-queue-next'));
    expect(repo.invoiceReminders[ids.last]?.length ?? 0, 1);
    expect(find.text('Share the next one · Anna Alder'), findsOneWidget);
  });

  testWidgets('a closed share sheet records nothing, says so, and keeps the '
      'line', (tester) async {
    outcome = FileShareOutcome.dismissed;
    await pump(tester);
    await tapReal(tester, _key('reminder-queue-next'));
    expect(repo.invoiceReminders[ids.last]?.length ?? 0, 0);
    expect(_key('reminder-queue-status-${ids.last}'), findsOneWidget);
    expect(
      find.text('Nothing was recorded: the share was closed.'),
      findsOneWidget,
    );
    expect(_key('reminder-queue-share-${ids.last}'), findsOneWidget);
  });

  testWidgets('sharing every line ends on a result page', (tester) async {
    await pump(tester);
    await tapReal(tester, _key('reminder-queue-next'));
    await tapReal(tester, _key('reminder-queue-next'));
    expect(find.text('2 reminders shared'), findsOneWidget);
    expect(find.text('Shared'), findsNWidgets(2));
    expect(repo.invoiceReminders[ids.first]?.length ?? 0, 1);
    expect(repo.invoiceReminders[ids.last]?.length ?? 0, 1);
  });

  testWidgets('shared, but the record failed: the line says so truly and '
      'offers Record, which records without sharing again', (tester) async {
    repo.failRecord = Exception('offline');
    await pump(tester);
    await tapReal(tester, _key('reminder-queue-next'));
    expect(shares, 1);
    expect(
      find.text(
        'Shared, but not recorded on the invoice. Record it: it will not be '
        'shared again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Could not be shared. Try again.'), findsNothing);
    expect(_key('reminder-queue-share-${ids.last}'), findsNothing);
    expect(
      find.text('Share the next one · Anna Alder'),
      findsOneWidget,
      reason: 'the bar never shares the letter that already left',
    );

    repo.failRecord = null;
    await tapReal(tester, _key('reminder-queue-record-${ids.last}'));
    expect(shares, 1, reason: 'recorded, not shared a second time');
    expect(repo.invoiceReminders[ids.last]?.length ?? 0, 1);
    expect(_key('reminder-queue-share-${ids.last}'), findsNothing);
  });

  testWidgets('the result page names what was shared and not recorded, with '
      'Record', (tester) async {
    await pump(tester);
    await tapReal(tester, _key('reminder-queue-next'));
    repo.failRecord = Exception('offline');
    await tapReal(tester, _key('reminder-queue-next'));
    expect(_key('reminder-queue-result'), findsOneWidget);
    expect(find.text('Shared, not recorded'), findsOneWidget);
    expect(shares, 2);
    repo.failRecord = null;
    await tapReal(tester, _key('reminder-queue-record-${ids.first}'));
    expect(shares, 2);
    expect(find.text('2 reminders shared'), findsOneWidget);
    expect(find.text('Shared, not recorded'), findsNothing);
  });

  testWidgets('Preview shows the letter on screen and Share is in its bar', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(_key('reminder-queue-preview-${ids.last}'));
    await tester.pumpAndSettle();
    expect(find.text('Please pay invoice'), findsOneWidget);
    expect(
      repo.invoiceReminders[ids.last]?.length ?? 0,
      0,
      reason: 'a preview shares nothing',
    );
    await tapReal(tester, _key('reminder-queue-preview-share'));
    expect(repo.invoiceReminders[ids.last]?.length ?? 0, 1);
    expect(find.text('Share the next one · Anna Alder'), findsOneWidget);
  });

  testWidgets('a customer who holds money received and not assigned is not '
      'chased: listed FIRST to be checked, with Match', (tester) async {
    holdingMoney = {'member-1'};
    await pump(tester);
    expect(
      find.text('CHECK FIRST: MONEY RECEIVED AND NOT ASSIGNED'),
      findsOneWidget,
    );
    expect(_key('reminder-queue-check-member-1'), findsOneWidget);
    // Anna (member-1) is not in the share groups; Ben (member-2) is.
    expect(find.text('Share the next one · Ben Birk'), findsOneWidget);
    expect(_key('reminder-queue-share-${ids.first}'), findsNothing);
    expect(
      tester.getTopLeft(_key('reminder-queue-check-member-1')).dy,
      lessThan(tester.getTopLeft(_key('reminder-queue-share-${ids.last}')).dy),
      reason: 'the check-first group comes before the share groups',
    );
    await tester.tap(_key('reminder-queue-match-member-1'));
    expect(matched, ['member-1']);
    expect(repo.invoiceReminders[ids.first]?.length ?? 0, 0);
  });

  for (final (width, scale) in [(320.0, 1.3), (390.0, 1.0), (1280.0, 1.0)]) {
    testWidgets('the queue keeps the rules at $width px, ×$scale', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, size: Size(width, 3000));
      expect(guardProblems(tester, width: width), isEmpty);
      semantics.dispose();
    });
  }

  // The pictures a pull request attaches (SHEET=1), at a phone's own height.
  testWidgets('sheet: the queue, a closed share, the result', (tester) async {
    await loadSheetFonts();
    await pump(tester);
    await writeSheet(tester, sheet: 'reminder-queue', name: 'queue');
    outcome = FileShareOutcome.dismissed;
    await tapReal(tester, _key('reminder-queue-next'));
    await writeSheet(tester, sheet: 'reminder-queue', name: 'closed-share');
    outcome = FileShareOutcome.sent;
    await tapReal(tester, _key('reminder-queue-next'));
    await tapReal(tester, _key('reminder-queue-next'));
    await writeSheet(tester, sheet: 'reminder-queue', name: 'result');
  });
}

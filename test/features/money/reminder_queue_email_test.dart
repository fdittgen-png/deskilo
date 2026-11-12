// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — the reminder queue by e-mail, as a person meets it: a reachable
// customer's line names the address and offers "Send by e-mail" beside
// "Share"; one without an address says so. "E-mail all reachable" first says
// what will happen and sends nothing on Cancel; on confirm each invoice is
// its own attempt, one after the other, and a refused one does not stop the
// rest. What a line shows is the server's row read again: a queue opened
// afresh shows the same truth without sending anything. A level that moved
// says so and is not retried; an e-mail nobody confirmed is decided.
import 'dart:typed_data';

import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/share/file_sharer.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/application/reminder_queue.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/domain/reminder_mail.dart';
import 'package:deskilo/features/money/presentation/invoicing/reminder_queue_screen.dart';
import 'package:deskilo/features/money/providers/reminder_mail_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/real_async.dart';

Finder _key(String k) => find.byKey(ValueKey(k));

/// The server as the queue sees it: each invoice's reach and its latest
/// e-mail, which a send changes as the fence would.
class _Server implements ReminderMail {
  _Server(this.reach);

  /// invoice id -> recipient, or null for no address on file.
  final Map<String, String?> reach;

  /// invoice id -> its latest e-mail as recorded.
  final Map<String, ReminderMailSend> recorded = {};

  /// invoice id -> what the next send answers: a state, or an error.
  final Map<String, Object> answers = {};

  final sends = <({String invoiceId, int level, String attemptId})>[];
  final decided = <bool>[];

  @override
  Future<Map<String, ReminderMailLine>> lines(
    String workspaceId,
    List<String> invoiceIds,
  ) async => {
    for (final id in invoiceIds)
      id: ReminderMailLine(
        target: reach[id] == null
            ? const ReminderMailTarget(
                available: false,
                reason: ReminderMailUnavailable.noAddress,
              )
            : ReminderMailTarget(available: true, recipient: reach[id]!),
        lastSend: recorded[id],
      ),
  };

  @override
  Future<ReminderMailSend> send({
    required String workspaceId,
    required String invoiceId,
    required int level,
    required String attemptId,
    required ReminderMailLetter letter,
  }) async {
    sends.add((invoiceId: invoiceId, level: level, attemptId: attemptId));
    final answer = answers.remove(invoiceId) ?? ReminderMailState.accepted;
    if (answer is Exception) throw answer;
    final send = ReminderMailSend(
      id: attemptId,
      invoiceId: invoiceId,
      level: level,
      state: answer as ReminderMailState,
      recipient: reach[invoiceId]!,
      reason: answer == ReminderMailState.refused ? 'provider_422' : '',
    );
    return recorded[invoiceId] = send;
  }

  @override
  Future<ReminderMailSend> resolve(
    String workspaceId,
    String attemptId, {
    required bool delivered,
  }) async {
    decided.add(delivered);
    final e = recorded.entries.firstWhere((e) => e.value.id == attemptId);
    return recorded[e.key] = ReminderMailSend(
      id: attemptId,
      invoiceId: e.key,
      level: e.value.level,
      state: delivered
          ? ReminderMailState.delivered
          : ReminderMailState.notDelivered,
      recipient: e.value.recipient,
    );
  }

  @override
  Future<ReminderMailTarget> target(String w, String i) async =>
      const ReminderMailTarget(available: false);

  @override
  Future<List<ReminderMailSend>> awaiting(String w, String i) async => const [];
}

void main() {
  late FakeMoneyRepository repo;
  late List<String> ids;
  late _Server server;
  final today = kTestNow;

  setUp(() async {
    repo = FakeMoneyRepository();
    ids = [];
    for (final member in ['member-1', 'member-2', 'member-3']) {
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
    // Anna and Ben can be e-mailed; Cleo has no address on file.
    server = _Server({
      ids[0]: 'anna@customer.test',
      ids[1]: 'ben@customer.test',
      ids[2]: null,
    });
  });

  ReminderQueue queue() => reminderQueueOf(
    [
      for (var i = 0; i < ids.length; i++)
        Receivable(
          invoiceId: ids[i],
          customerId: 'member-${i + 1}',
          customerName: ['Anna Alder', 'Ben Birk', 'Cleo Clay'][i],
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
  );

  Future<void> pump(WidgetTester tester) async {
    await pumpApp(
      tester,
      Consumer(
        builder: (context, ref, _) {
          ref.watch(authStateProvider);
          return ReminderQueueScreen(
            queue: queue(),
            today: today,
            onMatch: (_) {},
            previewOf: (line, invoice) async => (
              title: 'Reminder ${invoice.number}',
              report: const InvoiceReport(header: [], body: [], footer: []),
            ),
            letterOf: (line, invoice) async => (
              bytes: Uint8List.fromList([1]),
              fileName: 'reminder.pdf',
              message: 'Please pay',
            ),
            mailOf: (line, invoice) async => const ReminderMailLetter(
              language: 'en',
              subject: 'Reminder',
              text: 'Please pay',
              pdfBase64: 'JVBERi0=',
              fileName: 'reminder.pdf',
            ),
          );
        },
      ),
      size: const Size(390, 844),
      overrides: [
        ...standardTestOverrides(
          money: repo,
          auth: FakeAuthRepository.signedIn(),
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: const {
              'invoicing': true,
              'dunning': true,
              'paymentReminders': true,
              'reminderEmail': true,
            },
          ),
          fileSharer: ({
            required bytes,
            required fileName,
            required mimeType,
            text,
          }) async => FileShareOutcome.sent,
        ),
        reminderMailProvider.overrideWithValue(server),
      ],
    );
    await tester.runAsync(() async {
      await tester.pumpAndSettle();
    });
    await tester.pumpAndSettle();
  }

  /// Brings a line's widget to the middle of the list: lines are built
  /// lazily, and the bottom bar covers the list's last pixels.
  Future<void> show(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(
      f,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await Scrollable.ensureVisible(tester.element(f), alignment: 0.5);
    await tester.pumpAndSettle();
  }

  /// Nothing is being sent or decided: the bar's button acts again (or the
  /// result page took the screen).
  bool idle(WidgetTester tester) {
    final next = _key('reminder-queue-next');
    return next.evaluate().isEmpty ||
        tester.widget<FilledButton>(next).onPressed != null;
  }

  /// A tap whose work reads the archive and the server: real async work,
  /// polled until [until] holds (#1334), never waited a fixed time.
  Future<void> tapReal(
    WidgetTester tester,
    Finder f, {
    bool Function()? until,
  }) async {
    await tester.runAsync(() async {
      await tester.tap(f);
      await tester.pump();
      final done = until;
      if (done != null) {
        await untilReal(() async {
          await tester.pump();
          return done() && idle(tester);
        }, what: 'the queue\'s e-mail');
      }
      await tester.pumpAndSettle();
    });
    await tester.pumpAndSettle();
  }

  testWidgets('a reachable line names the address and offers the e-mail; one '
      'without an address says so', (tester) async {
    await pump(tester);
    expect(find.textContaining('anna@customer.test'), findsOneWidget);
    expect(_key('reminder-queue-email-${ids[0]}'), findsOneWidget);
    expect(_key('reminder-queue-email-${ids[2]}'), findsNothing);
    expect(
      find.text('This customer has no e-mail address on file'),
      findsOneWidget,
    );
    expect(_key('reminder-queue-share-${ids[2]}'), findsOneWidget);
  });

  testWidgets('one line by e-mail: the line then shows the server\'s row', (
    tester,
  ) async {
    await pump(tester);
    await show(tester, _key('reminder-queue-email-${ids[0]}'));
    await tapReal(
      tester,
      _key('reminder-queue-email-${ids[0]}'),
      until: () => server.sends.isNotEmpty,
    );
    expect(server.sends.single.invoiceId, ids[0]);
    expect(server.sends.single.level, 1);
    await show(tester, _key('reminder-queue-emailed-${ids[0]}'));
    expect(_key('reminder-queue-emailed-${ids[0]}'), findsOneWidget);
    expect(_key('reminder-queue-share-${ids[0]}'), findsNothing);
  });

  testWidgets('"E-mail all reachable" says what will happen; Cancel sends '
      'nothing', (tester) async {
    await pump(tester);
    await tapReal(tester, _key('reminder-queue-email-all'));
    expect(find.text('Send 2 reminders by e-mail?'), findsOneWidget);
    expect(find.text('Anna Alder · anna@customer.test'), findsOneWidget);
    expect(find.text('Ben Birk · ben@customer.test'), findsOneWidget);
    expect(
      find.text('1 line stays for sharing: no e-mail address on file.'),
      findsOneWidget,
    );
    await tapReal(tester, _key('reminder-queue-email-all-cancel'));
    expect(server.sends, isEmpty);
  });

  testWidgets('on confirm each invoice is its own attempt, and a refused one '
      'does not stop the rest', (tester) async {
    server.answers[ids[1]] = ReminderMailState.refused;
    await pump(tester);
    await tapReal(tester, _key('reminder-queue-email-all'));
    await tapReal(
      tester,
      _key('reminder-queue-email-all-confirm'),
      until: () => server.sends.length == 2,
    );
    expect([for (final s in server.sends) s.invoiceId], [ids[1], ids[0]]);
    expect(server.sends[0].attemptId, isNot(server.sends[1].attemptId));
    await show(tester, _key('reminder-queue-emailed-${ids[0]}'));
    expect(_key('reminder-queue-emailed-${ids[0]}'), findsOneWidget);
    expect(find.textContaining('the e-mail provider answered 422'), findsOne);
    expect(_key('reminder-queue-share-${ids[1]}'), findsOneWidget);
  });

  testWidgets('a queue opened afresh shows what the server recorded, sending '
      'nothing', (tester) async {
    server.recorded[ids[0]] = ReminderMailSend(
      id: 'earlier',
      invoiceId: ids[0],
      level: 1,
      state: ReminderMailState.accepted,
      recipient: 'anna@customer.test',
    );
    await pump(tester);
    await show(tester, _key('reminder-queue-emailed-${ids[0]}'));
    expect(_key('reminder-queue-emailed-${ids[0]}'), findsOneWidget);
    expect(server.sends, isEmpty);
  });

  testWidgets('a level that moved says so and is not retried', (tester) async {
    server.answers[ids[0]] = const ReminderMailLevelChanged();
    await pump(tester);
    await show(tester, _key('reminder-queue-email-${ids[0]}'));
    await tapReal(
      tester,
      _key('reminder-queue-email-${ids[0]}'),
      until: () => server.sends.isNotEmpty,
    );
    expect(server.sends, hasLength(1));
    expect(find.textContaining('left for the next pass'), findsOneWidget);
  });

  testWidgets('an e-mail nobody confirmed is decided by the person', (
    tester,
  ) async {
    server.answers[ids[0]] = ReminderMailState.unconfirmed;
    await pump(tester);
    await show(tester, _key('reminder-queue-email-${ids[0]}'));
    await tapReal(
      tester,
      _key('reminder-queue-email-${ids[0]}'),
      until: () => server.sends.isNotEmpty,
    );
    expect(_key('reminder-queue-arrived-${ids[0]}'), findsOneWidget);
    await show(tester, _key('reminder-queue-arrived-${ids[0]}'));
    await tapReal(
      tester,
      _key('reminder-queue-arrived-${ids[0]}'),
      until: () => server.decided.isNotEmpty,
    );
    expect(server.decided, [true]);
    await show(tester, _key('reminder-queue-emailed-${ids[0]}'));
    expect(_key('reminder-queue-emailed-${ids[0]}'), findsOneWidget);
  });

  test('the line\'s e-mail is the server\'s row at its own level', () {
    final line = QueuedReminder(_receivable, 2);
    ReminderMailLine row(int level, ReminderMailState state) =>
        ReminderMailLine(
          target: const ReminderMailTarget(available: true),
          lastSend: ReminderMailSend(
            id: 'a',
            invoiceId: 'i',
            level: level,
            state: state,
            recipient: 'x@y.z',
          ),
        );
    expect(queuedEmailOf(line, null), QueuedEmail.none);
    expect(
      queuedEmailOf(line, row(1, ReminderMailState.accepted)),
      QueuedEmail.none,
    );
    expect(
      queuedEmailOf(line, row(2, ReminderMailState.delivered)),
      QueuedEmail.sent,
    );
    expect(
      queuedEmailOf(line, row(2, ReminderMailState.pending)),
      QueuedEmail.toDecide,
    );
    expect(
      queuedEmailOf(line, row(2, ReminderMailState.refused)),
      QueuedEmail.refused,
    );
    expect(
      queuedEmailOf(line, row(2, ReminderMailState.notDelivered)),
      QueuedEmail.none,
    );
    final q = ReminderQueue([line]).withEmail({'i': QueuedEmail.toDecide});
    expect(q.hasLeft(line), isTrue, reason: 'never shared while to decide');
    expect(q.toDecide, [line]);
  });
}

final _receivable = Receivable(
  invoiceId: 'i',
  customerId: 'c',
  customerName: 'C',
  number: 'N',
  currency: 'EUR',
  totalMinor: 100,
  openMinor: 100,
  issuedOn: DateTime(2026),
  stage: ReceivableStage.open,
);

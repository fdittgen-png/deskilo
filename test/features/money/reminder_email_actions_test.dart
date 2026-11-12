// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — a reminder by e-mail, from the app's side: the channel is asked
// only while the feature is on; the customer's address is shown before
// anything leaves; a customer the e-mail cannot reach says why in words; an
// e-mail nobody confirmed leads to the person's decision; the letter's
// subject and text are in the customer's document language with the
// invoice's own currency, never the sender's on a guess; one attempt id per
// press, reused when the person retries it.
import 'package:deskilo/core/features/enabled_feature_keys.dart';
import 'package:deskilo/features/money/domain/reminder_mail.dart';
import 'package:deskilo/features/money/presentation/reminder_email_actions.dart';
import 'package:deskilo/features/money/presentation/widgets/reminder_evidence_list.dart';
import 'package:deskilo/features/money/providers/reminder_mail_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _invoice = Invoice(
  id: 'inv-1',
  workspaceId: 'ws',
  memberId: 'm',
  number: 'F-2026-0007',
  issuedAt: DateTime.utc(2026, 3),
  title: 'March',
  lines: const [InvoiceLine(label: 'Desk', amountCents: 12000)],
  totalCents: 12000,
  currency: 'CHF',
  memberName: 'A',
  memberAddress: '',
  workspaceName: 'W',
  workspaceAddress: '',
  issuerName: 'O',
  signature: '',
);

ReminderMailSend _send(ReminderMailState state, {String reason = ''}) =>
    ReminderMailSend(
      id: 'att-1',
      invoiceId: 'inv-1',
      level: 2,
      state: state,
      recipient: 'ana@customer.test',
      reason: reason,
    );

class _Mail implements ReminderMail {
  _Mail({
    this.reach = const ReminderMailTarget(
      available: true,
      recipient: 'ana@customer.test',
    ),
    this.waiting = const [],
    List<Object>? answers,
  }) : answers = answers ?? [_send(ReminderMailState.accepted)];

  final ReminderMailTarget reach;
  List<ReminderMailSend> waiting;

  /// What each send answers in turn: a send, or an error to throw.
  final List<Object> answers;
  final sent = <({String attemptId, int level, ReminderMailLetter letter})>[];
  final resolved = <bool>[];

  @override
  Future<ReminderMailTarget> target(
    String workspaceId,
    String invoiceId,
  ) async => reach;

  @override
  Future<List<ReminderMailSend>> awaiting(
    String workspaceId,
    String invoiceId,
  ) async => waiting;

  @override
  Future<ReminderMailSend> send({
    required String workspaceId,
    required String invoiceId,
    required int level,
    required String attemptId,
    required ReminderMailLetter letter,
  }) async {
    sent.add((attemptId: attemptId, level: level, letter: letter));
    final answer = answers.removeAt(0);
    if (answer is ReminderMailSend) return answer;
    if (answer is Exception) throw answer;
    throw answer as Error;
  }

  @override
  Future<ReminderMailSend> resolve(
    String workspaceId,
    String attemptId, {
    required bool delivered,
  }) async {
    resolved.add(delivered);
    return _send(
      delivered ? ReminderMailState.delivered : ReminderMailState.notDelivered,
    );
  }
}

const _pdf = (
  bytes: [0x25, 0x50, 0x44, 0x46],
  fileName: 'relance-2.pdf',
  title: 'Relance 2',
  language: 'fr',
);

Future<void> _pump(
  WidgetTester tester,
  _Mail mail, {
  bool emailOn = true,
  required Future<void> Function(BuildContext, WidgetRef) onTap,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reminderMailProvider.overrideWithValue(mail),
        enabledFeatureKeysProvider.overrideWithValue({
          if (emailOn) reminderEmailKey,
        }),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: Consumer(
              builder: (context, ref, _) => TextButton(
                key: const ValueKey('go'),
                onPressed: () => onTap(context, ref),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('go')));
  await tester.pumpAndSettle();
}

void main() {
  final l10n = AppLocalizationsEn();

  testWidgets(
    'with reminders by e-mail off, nothing is asked: the letter is shared',
    (tester) async {
      ReminderChannel? chosen;
      await _pump(
        tester,
        _Mail(),
        emailOn: false,
        onTap: (c, r) async =>
            chosen = await ReminderEmailFlow(c, r).choose(_invoice),
      );
      expect(chosen, ReminderChannel.share);
      expect(
        find.byKey(const ValueKey('reminder-channel-email')),
        findsNothing,
      );
    },
  );

  testWidgets('the channel list shows the address before anything leaves', (
    tester,
  ) async {
    ReminderChannel? chosen;
    await _pump(
      tester,
      _Mail(),
      onTap: (c, r) async =>
          chosen = await ReminderEmailFlow(c, r).choose(_invoice),
    );
    expect(
      find.text(l10n.reminderEmailTo('ana@customer.test')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('reminder-channel-email')));
    await tester.pumpAndSettle();
    expect(chosen, ReminderChannel.email);
  });

  for (final (reason, words) in [
    (ReminderMailUnavailable.noAddress, l10n.reminderEmailNoAddress),
    (ReminderMailUnavailable.senderNotConfigured, l10n.reminderEmailNoSender),
  ]) {
    testWidgets('a customer the e-mail cannot reach says why: ${reason.wire}', (
      tester,
    ) async {
      ReminderChannel? chosen;
      await _pump(
        tester,
        _Mail(reach: ReminderMailTarget(available: false, reason: reason)),
        onTap: (c, r) async =>
            chosen = await ReminderEmailFlow(c, r).choose(_invoice),
      );
      expect(find.text(words), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reminder-channel-email')));
      await tester.pumpAndSettle();
      expect(find.text(words), findsOneWidget, reason: 'the tile does not act');
      await tester.tap(find.byKey(const ValueKey('reminder-channel-share')));
      await tester.pumpAndSettle();
      expect(chosen, ReminderChannel.share);
    });
  }

  testWidgets('an e-mail nobody confirmed is decided by the person first', (
    tester,
  ) async {
    final mail = _Mail(waiting: [_send(ReminderMailState.unconfirmed)]);
    ReminderChannel? chosen = ReminderChannel.share;
    await _pump(
      tester,
      mail,
      onTap: (c, r) async =>
          chosen = await ReminderEmailFlow(c, r).choose(_invoice),
    );
    expect(
      find.text(l10n.purchaseOrderSendAwaits('ana@customer.test')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('reminder-email-arrived')));
    await tester.pumpAndSettle();
    expect(mail.resolved, [true]);
    expect(chosen, isNull, reason: 'nothing is sent in the same press');
  });

  testWidgets(
    'the letter leaves in the customer\'s language and the invoice\'s currency',
    (tester) async {
      final mail = _Mail();
      await _pump(
        tester,
        mail,
        onTap: (c, r) => ReminderEmailFlow(
          c,
          r,
        ).email(_invoice, level: 2, owedCents: 4500, pdf: _pdf),
      );
      expect(mail.sent, hasLength(1));
      final letter = mail.sent.single.letter;
      expect(letter.language, 'fr');
      expect(letter.subject, 'Relance 2 F-2026-0007');
      expect(letter.text, startsWith('Rappel amical'));
      expect(letter.text, contains('CHF'));
      expect(letter.text, contains('45'));
      expect(
        find.text(l10n.purchaseOrderSentTo('ana@customer.test')),
        findsOneWidget,
      );
    },
  );

  testWidgets('without the customer\'s language nothing is e-mailed', (
    tester,
  ) async {
    final mail = _Mail();
    await _pump(
      tester,
      mail,
      onTap: (c, r) => ReminderEmailFlow(c, r).email(
        _invoice,
        level: 2,
        owedCents: 4500,
        pdf: (
          bytes: _pdf.bytes,
          fileName: _pdf.fileName,
          title: _pdf.title,
          language: '',
        ),
      ),
    );
    expect(mail.sent, isEmpty);
    expect(find.text(l10n.reminderEmailNoLanguage), findsOneWidget);
  });

  testWidgets('a retry of the same press reuses its attempt id', (
    tester,
  ) async {
    final mail = _Mail(
      answers: [StateError('offline'), _send(ReminderMailState.accepted)],
    );
    await _pump(
      tester,
      mail,
      onTap: (c, r) => ReminderEmailFlow(
        c,
        r,
      ).email(_invoice, level: 2, owedCents: 4500, pdf: _pdf),
    );
    await tester.tap(find.byKey(const ValueKey('reminder-email-retry')));
    await tester.pumpAndSettle();
    expect(mail.sent, hasLength(2));
    expect(mail.sent[0].attemptId, mail.sent[1].attemptId);
  });

  testWidgets(
    '"decide it by hand" leads to the decision, and nothing is sent again',
    (tester) async {
      final mail = _Mail(
        answers: [const ReminderMailAwaitsDecision()],
        waiting: [_send(ReminderMailState.pending)],
      );
      await _pump(
        tester,
        mail,
        onTap: (c, r) => ReminderEmailFlow(
          c,
          r,
        ).email(_invoice, level: 2, owedCents: 4500, pdf: _pdf),
      );
      await tester.tap(find.byKey(const ValueKey('reminder-email-lost')));
      await tester.pumpAndSettle();
      expect(mail.resolved, [false]);
      expect(mail.sent, hasLength(1));
    },
  );

  testWidgets('a refusal says no reminder was recorded', (tester) async {
    final mail = _Mail(
      answers: [_send(ReminderMailState.refused, reason: 'provider_422')],
    );
    await _pump(
      tester,
      mail,
      onTap: (c, r) => ReminderEmailFlow(
        c,
        r,
      ).email(_invoice, level: 2, owedCents: 4500, pdf: _pdf),
    );
    expect(
      find.text(l10n.reminderEmailRefused(l10n.mailRefusalProvider('422'))),
      findsOneWidget,
    );
  });

  test('the history names the e-mail provider for an e-mailed reminder', () {
    expect(
      reminderStatusLabel(l10n, 'provider_accepted', email: true),
      l10n.reminderStatusEmailAccepted,
    );
    expect(
      reminderStatusLabel(l10n, 'provider_accepted'),
      l10n.reminderStatusAccepted,
    );
  });
}

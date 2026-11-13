// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — an invoice by e-mail. The e-mail's text follows the invoice's
// state in the customer's language (what is still owed and by when, that
// it is paid, or what a credit note is for — never "0.00 due"). The
// attachment is exactly the builder's output for the customer's language;
// without that language nothing leaves. The page shows the server's rows:
// to whom it would go or why not, "E-mailed to … on …" with "Send again",
// the decision on an e-mail nobody confirmed. One attempt id per press,
// reused when the person retries it.
import 'dart:convert';

import 'package:deskilo/core/features/enabled_feature_keys.dart';
import 'package:deskilo/features/money/application/invoice_mail_commands.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/domain/invoice_mail.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/reminder_mail.dart';
import 'package:deskilo/features/money/presentation/invoice_email_actions.dart';
import 'package:deskilo/features/money/providers/invoice_mail_providers.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo/l10n/app_localizations_fr.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

final _invoice = Invoice(
  id: 'inv-1',
  workspaceId: 'ws',
  memberId: 'm',
  number: 'F-2026-0009',
  issuedAt: DateTime.utc(2026, 3),
  title: 'March',
  lines: const [InvoiceLine(label: 'Desk', amountCents: 12000)],
  totalCents: 12000,
  currency: 'EUR',
  memberName: 'A',
  memberAddress: '',
  workspaceName: 'W',
  workspaceAddress: '',
  issuerName: 'O',
  signature: '',
);

InvoiceMailSend _send(
  ReminderMailState state, {
  InvoiceMailKind kind = InvoiceMailKind.first,
}) => InvoiceMailSend(
  id: 'att-1',
  invoiceId: 'inv-1',
  kind: kind,
  state: state,
  recipient: 'ana@customer.test',
  finishedAt: DateTime.utc(2026, 3, 4, 10),
);

class _Mail implements InvoiceMail {
  _Mail(this.view, {List<Object>? answers})
    : answers = answers ?? [_send(ReminderMailState.accepted)];

  InvoiceMailView view;
  final List<Object> answers;
  final sent =
      <({InvoiceMailKind kind, String attemptId, InvoiceMailLetter letter})>[];
  final resolved = <bool>[];

  @override
  Future<InvoiceMailView> state(String workspaceId, String invoiceId) async =>
      view;

  @override
  Future<InvoiceMailSend> send({
    required String workspaceId,
    required String invoiceId,
    required InvoiceMailKind kind,
    required String attemptId,
    required InvoiceMailLetter letter,
  }) async {
    sent.add((kind: kind, attemptId: attemptId, letter: letter));
    final answer = answers.removeAt(0);
    if (answer is InvoiceMailSend) return answer;
    if (answer is Exception) throw answer;
    throw answer as Error;
  }

  @override
  Future<InvoiceMailSend> resolve(
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

const _reachable = InvoiceMailView(
  available: true,
  recipient: 'ana@customer.test',
);

Future<void> _pump(
  WidgetTester tester,
  _Mail mail, {
  Future<void> Function(BuildContext, WidgetRef)? onTap,
  Invoice? invoice,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        invoiceMailProvider.overrideWithValue(mail),
        enabledFeatureKeysProvider.overrideWithValue({invoiceEmailKey}),
        // The business's own rules: the due date the e-mail states.
        dunningRulesProvider.overrideWith((ref) async => const DunningRules()),
        invoicePdfTemplateProvider.overrideWith(
          (ref) async => InvoicePdfTemplate.empty,
        ),
        invoiceMatchesProvider.overrideWith((ref) async => const {}),
        currentWorkspaceProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => Column(
              children: [
                InvoiceEmailPanel(invoice: invoice ?? _invoice),
                if (onTap != null)
                  TextButton(
                    key: const ValueKey('go'),
                    onPressed: () => onTap(context, ref),
                    child: const Text('go'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // The app formats dates in every supported language from its start.
  setUpAll(initializeDateFormatting);
  final en = AppLocalizationsEn();
  final fr = AppLocalizationsFr();
  const doc = (
    title: '',
    language: 'fr',
    pdfBase64: 'JVBERi0=',
    fileName: 'F-2026-0009.pdf',
  );

  group(
    'the text follows the invoice\'s state, in the customer\'s language',
    () {
      final commands = InvoiceMailCommands(_Mail(_reachable));
      test('something owed: what is still owed and by when', () {
        final letter = commands.letter(
          l10n: fr,
          document: doc,
          number: 'F-2026-0009',
          amounts: (
            currency: 'EUR',
            totalCents: 12000,
            owedCents: 4500,
            dueOn: DateTime(2026, 4, 2),
          ),
        );
        expect(letter.subject, fr.billInvoiceCard('F-2026-0009'));
        expect(letter.text, contains('45,00'));
        expect(letter.text, contains('2026'));
        expect(letter.language, 'fr');
      });
      test('nothing owed: the total and that it is paid, never "0.00 due"', () {
        final letter = commands.letter(
          l10n: fr,
          document: doc,
          number: 'F-2026-0009',
          amounts: (
            currency: 'EUR',
            totalCents: 12000,
            owedCents: 0,
            dueOn: null,
          ),
        );
        expect(letter.text, contains('120,00'));
        expect(letter.text, contains('Elle est réglée'));
        expect(letter.text, isNot(contains(' 0,00')));
      });
      test('a credit note says what it is for', () {
        final letter = commands.letter(
          l10n: en,
          document: doc,
          number: 'C-1',
          amounts: (
            currency: 'EUR',
            totalCents: -3000,
            owedCents: -3000,
            dueOn: null,
          ),
        );
        expect(letter.subject, en.billCreditNoteCard('C-1'));
        expect(letter.text, contains('30'));
      });
    },
  );

  testWidgets('a reachable customer: the page names the address and sends '
      'the builder\'s own bytes in the customer\'s language', (tester) async {
    final mail = _Mail(_reachable);
    final asked = <String>[];
    await _pump(
      tester,
      mail,
      onTap: (c, r) => InvoiceEmailFlow(
        c,
        r,
        languageOf: (_) async => 'fr',
        documentOf: (invoice, language) async {
          asked.add(language);
          return (bytes: [1, 2, 3], fileName: 'F-2026-0009.pdf');
        },
      ).send(_invoice, InvoiceMailKind.first),
    );
    expect(find.text(en.reminderEmailTo('ana@customer.test')), findsOneWidget);
    expect(find.byKey(const ValueKey('invoice-email-send')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('go')));
    await tester.pumpAndSettle();
    expect(asked, ['fr']);
    expect(mail.sent.single.kind, InvoiceMailKind.first);
    expect(mail.sent.single.letter.pdfBase64, base64Encode([1, 2, 3]));
    expect(mail.sent.single.letter.language, 'fr');
  });

  testWidgets('an issued invoice is e-mailed in the language frozen with it (#3850)', (
    tester,
  ) async {
    final mail = _Mail(_reachable);
    String? built;
    await _pump(
      tester,
      mail,
      invoice: _invoice.copyWith(documentLanguage: 'de', formatLocale: 'de_FR'),
      onTap: (c, r) => InvoiceEmailFlow(
        c,
        r,
        documentOf: (invoice, language) async {
          built = language;
          return (bytes: [1], fileName: 'x.pdf');
        },
      ).send(_invoice.copyWith(documentLanguage: 'de', formatLocale: 'de_FR'),
          InvoiceMailKind.first),
    );
    await tester.tap(find.byKey(const ValueKey('go')));
    await tester.pumpAndSettle();
    expect(built, 'de');
    expect(mail.sent.single.letter.language, 'de');
  });

  testWidgets('a retry of the same press reuses its attempt id', (
    tester,
  ) async {
    final mail = _Mail(
      _reachable,
      answers: [StateError('offline'), _send(ReminderMailState.accepted)],
    );
    await _pump(
      tester,
      mail,
      onTap: (c, r) => InvoiceEmailFlow(
        c,
        r,
        languageOf: (_) async => 'en',
        documentOf: (invoice, language) async =>
            (bytes: [1], fileName: 'x.pdf'),
      ).send(_invoice, InvoiceMailKind.first),
    );
    await tester.tap(find.byKey(const ValueKey('go')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-email-retry')));
    await tester.pumpAndSettle();
    expect(mail.sent, hasLength(2));
    expect(mail.sent[0].attemptId, mail.sent[1].attemptId);
  });

  testWidgets('once it left: "E-mailed to … on …" and "Send again"', (
    tester,
  ) async {
    await _pump(
      tester,
      _Mail(
        InvoiceMailView(
          available: true,
          recipient: 'ana@customer.test',
          sends: [_send(ReminderMailState.accepted)],
        ),
      ),
    );
    expect(
      find.textContaining('E-mailed to ana@customer.test on'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('invoice-email-again')), findsOneWidget);
    expect(find.byKey(const ValueKey('invoice-email-send')), findsNothing);
  });

  testWidgets('an e-mail nobody confirmed is decided, never sent again', (
    tester,
  ) async {
    final mail = _Mail(
      InvoiceMailView(
        available: true,
        recipient: 'ana@customer.test',
        sends: [_send(ReminderMailState.unconfirmed)],
      ),
    );
    await _pump(tester, mail);
    expect(find.byKey(const ValueKey('invoice-email-send')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('invoice-email-arrived')));
    await tester.pumpAndSettle();
    expect(mail.resolved, [true]);
  });

  testWidgets('a voided invoice or a customer without an address says why', (
    tester,
  ) async {
    await _pump(
      tester,
      _Mail(
        const InvoiceMailView(
          available: false,
          reason: InvoiceMailUnavailable.voided,
        ),
      ),
    );
    expect(find.text(en.invoiceEmailVoided), findsOneWidget);
    expect(find.byKey(const ValueKey('invoice-email-send')), findsNothing);
  });
}

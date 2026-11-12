// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — the reminder e-mail command without a screen: the function's
// refusals become domain refusals in data/, and each answer becomes what a
// person acts on: the fence leads to the e-mails to decide, a moved level
// and a refusal send nothing, and anything else may not have reached the
// server (a retry with the same id is safe). The letter is in the
// customer's language and the invoice's currency.
import 'package:deskilo/features/money/application/reminder_mail_commands.dart';
import 'package:deskilo/features/money/data/supabase_reminder_mail.dart';
import 'package:deskilo/features/money/domain/reminder_mail.dart';
import 'package:deskilo/l10n/app_localizations_de.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

const _waiting = ReminderMailSend(
  id: 'att-1',
  invoiceId: 'inv-1',
  level: 1,
  state: ReminderMailState.unconfirmed,
  recipient: 'ana@customer.test',
);

class _Mail implements ReminderMail {
  _Mail(this.failure);
  final Object failure;

  @override
  Future<ReminderMailTarget> target(String w, String i) async =>
      const ReminderMailTarget(available: true);

  @override
  Future<Map<String, ReminderMailLine>> lines(
    String workspaceId,
    List<String> invoiceIds,
  ) async => const {};

  @override
  Future<List<ReminderMailSend>> awaiting(String w, String i) async => [
    _waiting,
  ];

  @override
  Future<ReminderMailSend> send({
    required String workspaceId,
    required String invoiceId,
    required int level,
    required String attemptId,
    required ReminderMailLetter letter,
  }) => Future.error(failure);

  @override
  Future<ReminderMailSend> resolve(
    String w,
    String a, {
    required bool delivered,
  }) async => _waiting;
}

Future<ReminderMailAnswer> _answer(Object failure) =>
    ReminderMailCommands(_Mail(failure)).send(
      workspaceId: 'ws',
      invoiceId: 'inv-1',
      level: 1,
      attemptId: 'att-1',
      letter: const ReminderMailLetter(
        language: 'de',
        subject: 's',
        text: 't',
        pdfBase64: 'JVBERi0=',
        fileName: 'f.pdf',
      ),
    );

void main() {
  test('the function\'s refusals become domain refusals', () {
    expect(
      SupabaseReminderMail.refusalOf(
        const FunctionException(status: 409, details: {'code': '40001'}),
      ),
      isA<ReminderMailLevelChanged>(),
    );
    expect(
      SupabaseReminderMail.refusalOf(
        const FunctionException(status: 409, details: {'code': '55000'}),
      ),
      isA<ReminderMailAwaitsDecision>(),
    );
    expect(
      SupabaseReminderMail.refusalOf(
        const FunctionException(status: 403, details: {'error': 'not allowed'}),
      ),
      isA<ReminderMailRefused>(),
    );
    expect(
      SupabaseReminderMail.refusalOf(const FunctionException(status: 502)),
      isNull,
      reason: 'a 5xx may not have reached the database',
    );
  });

  test('each refusal becomes what a person acts on', () async {
    expect(
      await _answer(const ReminderMailAwaitsDecision()),
      isA<ReminderMailToDecide>().having((a) => a.waiting, 'waiting', [
        _waiting,
      ]),
    );
    expect(
      await _answer(const ReminderMailLevelChanged()),
      isA<ReminderMailLevelMoved>(),
    );
    expect(
      await _answer(const ReminderMailRefused('not allowed')),
      isA<ReminderMailNotSent>(),
    );
    expect(await _answer(StateError('offline')), isA<ReminderMailUnreached>());
  });

  test(
    'the letter is in the customer\'s language and the invoice\'s currency',
    () {
      final letter = ReminderMailCommands(_Mail(StateError('-'))).letter(
        l10n: AppLocalizationsDe(),
        document: (
          title: 'Mahnung 2',
          language: 'de',
          pdfBase64: 'JVBERi0=',
          fileName: 'mahnung.pdf',
        ),
        number: 'R-7',
        currency: 'GBP',
        owedCents: 123456,
      );
      expect(letter.subject, 'Mahnung 2 R-7');
      expect(letter.text, contains('R-7'));
      expect(letter.text, contains('1.234,56'));
      expect(letter.text, contains('£'));
    },
  );
}

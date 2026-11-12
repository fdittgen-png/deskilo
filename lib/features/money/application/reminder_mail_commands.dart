// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — a reminder by e-mail as a command: what the server says about
// one invoice's customer, the letter composed in the customer's language,
// the send and its answer as something a person acts on, and the decision
// on an e-mail nobody confirmed. The dialogs stay in presentation; this is
// the part the MCP or the recorder could call without a BuildContext.
import '../../../core/i18n/money_format.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/reminder_mail.dart';

/// The built letter: its title, file and language as the report system
/// made them.
typedef ReminderMailDocument = ({
  String title,
  String language,
  String pdfBase64,
  String fileName,
});

/// What came of one press of "send by e-mail".
sealed class ReminderMailAnswer {
  const ReminderMailAnswer();
}

/// The server answered: accepted, refused by the provider, or unconfirmed.
class ReminderMailAnswered extends ReminderMailAnswer {
  const ReminderMailAnswered(this.send);
  final ReminderMailSend send;
}

/// The level moved on since the letter was built: nothing left.
class ReminderMailLevelMoved extends ReminderMailAnswer {
  const ReminderMailLevelMoved();
}

/// An earlier e-mail has no confirmed outcome; [waiting] are those a person
/// decides (empty when none could be read: the person checks first).
class ReminderMailToDecide extends ReminderMailAnswer {
  const ReminderMailToDecide(this.waiting);
  final List<ReminderMailSend> waiting;
}

/// The server refused it (rights, the invoice, the address): nothing left.
class ReminderMailNotSent extends ReminderMailAnswer {
  const ReminderMailNotSent();
}

/// The request may not have reached the server: the same attempt id makes
/// a retry safe.
class ReminderMailUnreached extends ReminderMailAnswer {
  const ReminderMailUnreached(this.error);
  final Object error;
}

class ReminderMailCommands {
  const ReminderMailCommands(this._mail);

  final ReminderMail _mail;

  /// Whether the customer of [invoiceId] can be e-mailed, and the e-mails
  /// of it nobody confirmed.
  Future<({ReminderMailTarget target, List<ReminderMailSend> waiting})> reach(
    String workspaceId,
    String invoiceId,
  ) async => (
    waiting: await _mail.awaiting(workspaceId, invoiceId),
    target: await _mail.target(workspaceId, invoiceId),
  );

  /// The queue's invoices as the server sees them: reachable or why not,
  /// and each one's latest e-mail as recorded (0728).
  Future<Map<String, ReminderMailLine>> lines(
    String workspaceId,
    List<String> invoiceIds,
  ) => invoiceIds.isEmpty
      ? Future.value(const {})
      : _mail.lines(workspaceId, invoiceIds);

  /// The letter as it leaves, in the [document]'s language ([l10n] is that
  /// language's bundle): the subject is the letter's title and the invoice
  /// number, the text what is still owed in the invoice's own [currency].
  ReminderMailLetter letter({
    required AppLocalizations l10n,
    required ReminderMailDocument document,
    required String number,
    required String currency,
    required int owedCents,
  }) => ReminderMailLetter(
    language: document.language,
    subject: '${document.title} $number',
    text: l10n.invoiceReminderMessage(
      number,
      moneyFormat(currency, locale: document.language).formatMinor(owedCents),
    ),
    pdfBase64: document.pdfBase64,
    fileName: document.fileName,
  );

  /// Sends [letter] once for [attemptId]; a retry passes the same id.
  Future<ReminderMailAnswer> send({
    required String workspaceId,
    required String invoiceId,
    required int level,
    required String attemptId,
    required ReminderMailLetter letter,
  }) async {
    try {
      return ReminderMailAnswered(
        await _mail.send(
          workspaceId: workspaceId,
          invoiceId: invoiceId,
          level: level,
          attemptId: attemptId,
          letter: letter,
        ),
      );
    } on ReminderMailRefusal catch (refusal, st) {
      TraceLogger.instance.error(
        'money',
        'reminder e-mail refused',
        error: refusal,
        stackTrace: st,
      );
      return switch (refusal) {
        ReminderMailLevelChanged() => const ReminderMailLevelMoved(),
        ReminderMailAwaitsDecision() => ReminderMailToDecide(
          await _mail.awaiting(workspaceId, invoiceId),
        ),
        ReminderMailRefused() => const ReminderMailNotSent(),
      };
    } on Object catch (e, st) {
      TraceLogger.instance.error(
        'money',
        'reminder e-mail failed',
        error: e,
        stackTrace: st,
      );
      return ReminderMailUnreached(e);
    }
  }

  /// A person decides an e-mail nobody could confirm.
  Future<ReminderMailSend> decide(
    String workspaceId,
    ReminderMailSend send, {
    required bool delivered,
  }) => _mail.resolve(workspaceId, send.id, delivered: delivered);
}

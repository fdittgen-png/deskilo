// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — an invoice by e-mail as a command: what the server says about the
// invoice's e-mail, the e-mail composed in the customer's language (its
// text follows the invoice's state: what is still owed and by when, or that
// it is paid — never "0.00 due"), the send and its answer as something a
// person acts on, and the decision on an e-mail nobody confirmed. The
// dialogs stay in presentation.
import 'package:intl/intl.dart';

import '../../../core/i18n/money_format.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/invoice_mail.dart';
import '../domain/reminder_mail.dart';
import 'reminder_mail_commands.dart' show ReminderMailDocument;

/// What came of one press of "send by e-mail" or "send again".
sealed class InvoiceMailAnswer {
  const InvoiceMailAnswer();
}

/// The server answered: accepted, refused by the provider, or unconfirmed.
class InvoiceMailAnswered extends InvoiceMailAnswer {
  const InvoiceMailAnswered(this.send);
  final InvoiceMailSend send;
}

/// An earlier e-mail has no confirmed outcome; [waiting] is the one a
/// person decides (null when none could be read: the person checks first).
class InvoiceMailToDecide extends InvoiceMailAnswer {
  const InvoiceMailToDecide(this.waiting);
  final InvoiceMailSend? waiting;
}

/// The server refused it (rights, the invoice, the address): nothing left.
class InvoiceMailNotSent extends InvoiceMailAnswer {
  const InvoiceMailNotSent();
}

/// The request may not have reached the server: the same attempt id makes
/// a retry safe.
class InvoiceMailUnreached extends InvoiceMailAnswer {
  const InvoiceMailUnreached(this.error);
  final Object error;
}

/// What the invoice owes as the e-mail states it.
typedef InvoiceMailAmounts = ({
  String currency,
  int totalCents,
  int owedCents,
  DateTime? dueOn,
});

class InvoiceMailCommands {
  const InvoiceMailCommands(this._mail);

  final InvoiceMail _mail;

  /// What the invoice page shows for [invoiceId].
  Future<InvoiceMailView> view(String workspaceId, String invoiceId) =>
      _mail.state(workspaceId, invoiceId);

  /// The e-mail as it leaves, in the [document]'s language ([l10n] is that
  /// language's bundle): the subject is the document's own title and
  /// number; the text says what is still owed and by when, that it is paid,
  /// or what a credit note is for.
  InvoiceMailLetter letter({
    required AppLocalizations l10n,
    required ReminderMailDocument document,
    required String number,
    required InvoiceMailAmounts amounts,
  }) {
    final language = document.language;
    String money(int cents) =>
        moneyFormat(amounts.currency, locale: language).formatMinor(cents);
    final due = amounts.dueOn;
    final credit = amounts.totalCents < 0;
    return InvoiceMailLetter(
      language: language,
      subject: credit
          ? l10n.billCreditNoteCard(number)
          : l10n.billInvoiceCard(number),
      text: credit
          ? l10n.invoiceEmailTextCredit(number, money(-amounts.totalCents))
          : amounts.owedCents <= 0
          ? l10n.invoiceEmailTextPaid(number, money(amounts.totalCents))
          : due == null
          ? l10n.invoiceEmailTextOwed(number, money(amounts.owedCents))
          : l10n.invoiceEmailTextOwedBy(
              number,
              money(amounts.owedCents),
              DateFormat.yMMMd(language).format(due),
            ),
      pdfBase64: document.pdfBase64,
      fileName: document.fileName,
    );
  }

  /// Sends [letter] as [kind] once for [attemptId]; a retry passes the same
  /// id.
  Future<InvoiceMailAnswer> send({
    required String workspaceId,
    required String invoiceId,
    required InvoiceMailKind kind,
    required String attemptId,
    required InvoiceMailLetter letter,
  }) async {
    try {
      return InvoiceMailAnswered(
        await _mail.send(
          workspaceId: workspaceId,
          invoiceId: invoiceId,
          kind: kind,
          attemptId: attemptId,
          letter: letter,
        ),
      );
    } on ReminderMailRefusal catch (refusal, st) {
      TraceLogger.instance.error(
        'money',
        'invoice e-mail refused',
        error: refusal,
        stackTrace: st,
      );
      if (refusal is! ReminderMailAwaitsDecision) {
        return const InvoiceMailNotSent();
      }
      final view = await _mail.state(workspaceId, invoiceId);
      return InvoiceMailToDecide(
        view.sends.where((s) => s.awaitsDecision).firstOrNull,
      );
    } on Object catch (e, st) {
      TraceLogger.instance.error(
        'money',
        'invoice e-mail failed',
        error: e,
        stackTrace: st,
      );
      return InvoiceMailUnreached(e);
    }
  }

  /// A person decides an e-mail nobody could confirm.
  Future<InvoiceMailSend> decide(
    String workspaceId,
    InvoiceMailSend send, {
    required bool delivered,
  }) => _mail.resolve(workspaceId, send.id, delivered: delivered);
}

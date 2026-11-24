// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1532 / #1449 — sending a dunning reminder is a decision, not a form.
//
// The rule is the ORDER, and it is worth a name: the letter goes out
// first, and the level is recorded only when something actually left the
// device. It used to record and then share, so cancelling the share
// sheet escalated the member anyway — and the next attempt sent a
// level-2 letter for a level-1 nobody ever received. A dunning ladder is
// a legal instrument; its steps are supposed to have happened.
//
// ADR 0024's shape, like `record_payment.dart` and `book_repartition.dart`:
// pure Dart with its collaborators handed in, because the order is the
// whole behaviour and a rule only a widget can exercise is a rule
// nothing checks.
import 'dart:typed_data';

import '../../../core/data/app_failure_from.dart';
import '../../../core/failure/app_failure.dart';
import '../../../core/share/file_sharer.dart';
import '../domain/invoice_commands.dart';

/// The share sheet was closed: nothing left the device, and nothing was
/// recorded. A refusal by the person, before anything was sent, so the
/// caller can say "nothing happened" — neither a success nor a failure.
final class _ReminderNotSent implements TypedRefusal {
  const _ReminderNotSent();
}

/// Whether [outcome] is a reminder the person did not send.
bool isReminderNotSent(CommandOutcome<int> outcome) =>
    outcome is CommandRefused<int> && outcome.refusal.cause is _ReminderNotSent;

/// Shares [bytes] as [fileName], then records the reminder on [invoiceId]
/// if it went: done with the level THIS letter carried, refused with
/// the person's own "not sent" ([isReminderNotSent]) when the share sheet
/// was closed, or refused / not
/// reached as the share or the record answered.
///
/// [FileShareOutcome.unknown] counts as sent, deliberately: on a platform
/// that can never say what the user did, refusing to record would mean a
/// ladder that never advances at all. That trade is the open question on
/// #1532 and is pinned by a test so changing it is a decision.
Future<CommandOutcome<int>> sendReminder({
  required InvoiceCommands repository,
  required FileSharer share,
  required String invoiceId,
  required int level,
  required Uint8List bytes,
  required String fileName,
  required String message,
}) => runCommand(
  () => _shareThenRecord(repository, share, invoiceId, level, (
    bytes: bytes,
    fileName: fileName,
    message: message,
  )),
  what: 'reminder not sent',
);

/// The order itself: the letter goes out, and the level is recorded only
/// if it did.
Future<int> _shareThenRecord(
  InvoiceCommands repository,
  FileSharer share,
  String invoiceId,
  int level,
  ({Uint8List bytes, String fileName, String message}) letter,
) async {
  final outcome = await share(
    bytes: letter.bytes,
    fileName: letter.fileName,
    mimeType: 'application/pdf',
    text: letter.message,
  );
  if (outcome == FileShareOutcome.dismissed) throw const _ReminderNotSent();
  await repository.remindInvoice(invoiceId);
  return level;
}

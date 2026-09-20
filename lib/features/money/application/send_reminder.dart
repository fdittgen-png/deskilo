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

import '../../../core/share/file_sharer.dart';
import '../domain/money_repository.dart';

/// What happened to a reminder somebody tried to send.
sealed class SendReminderOutcome {
  const SendReminderOutcome();
}

/// The letter went out and the level is on the record.
class ReminderSent extends SendReminderOutcome {
  const ReminderSent(this.level);

  /// The level THIS letter carried.
  final int level;
}

/// The share sheet was closed: nothing left the device, and nothing was
/// recorded. Its own outcome because "nothing happened" is what the
/// caller has to be able to say — neither a success nor a failure.
class ReminderNotSent extends SendReminderOutcome {
  const ReminderNotSent();
}

/// Shares [bytes] as [fileName], then records the reminder on [invoiceId]
/// if it went.
///
/// [FileShareOutcome.unknown] counts as sent, deliberately: on a platform
/// that can never say what the user did, refusing to record would mean a
/// ladder that never advances at all. That trade is the open question on
/// #1532 and is pinned by a test so changing it is a decision.
Future<SendReminderOutcome> sendReminder({
  required MoneyRepository repository,
  required FileSharer share,
  required String invoiceId,
  required int level,
  required Uint8List bytes,
  required String fileName,
  required String message,
}) async {
  final outcome = await share(
    bytes: bytes,
    fileName: fileName,
    mimeType: 'application/pdf',
    text: message,
  );
  if (outcome == FileShareOutcome.dismissed) return const ReminderNotSent();
  await repository.remindInvoice(invoiceId);
  return ReminderSent(level);
}

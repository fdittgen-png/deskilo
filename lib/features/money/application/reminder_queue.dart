// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-f -- the reminders shared BY HAND: a queue grouped by level, one
// share per line, and an honest account of what was shared. When the rules
// send reminders by themselves the queue does not exist.
//
// Sharing is not sending: the letter goes through the device's share sheet and
// the level is recorded only if it left (`sendReminder`, #1532). A dismissed
// sheet records nothing and the queue says so; the line stays in it. Nothing
// here claims a delivery the server has not recorded.
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../core/share/file_sharer.dart';
import '../domain/invoice_commands.dart';
import '../domain/reminder_mail.dart';
import 'receivables.dart';
import 'receivables_answers.dart';
import 'send_reminder.dart';

/// One reminder waiting to be shared.
@immutable
class QueuedReminder {
  const QueuedReminder(this.receivable, this.level);

  final Receivable receivable;

  /// The level the rules say is due (1-based).
  final int level;

  String get invoiceId => receivable.invoiceId;
}

/// What became of a line.
enum ReminderHandled {
  /// It left the device and the level is recorded.
  shared,

  /// The sheet was dismissed: nothing left, nothing was recorded.
  notRecorded,

  /// It left the device, but recording its level failed: it is never
  /// shared again, only recorded (`recordQueuedReminder`).
  sharedNotRecorded,

  /// The letter or the share failed: nothing left the device.
  failed,
}

/// #3673 — what the server recorded for a line's reminder e-mail at the
/// line's own level (0728's rows, never what the app remembers).
enum QueuedEmail {
  /// No e-mail of this level, or one a person said did not arrive.
  none,

  /// The provider accepted it, or a person confirmed it arrived.
  sent,

  /// No confirmed outcome: a person decides whether it arrived.
  toDecide,

  /// Refused: nothing left, nothing counted; it may be sent or shared.
  refused,
}

/// The state of [line]'s e-mail in [mail], the server's row for its invoice.
QueuedEmail queuedEmailOf(QueuedReminder line, ReminderMailLine? mail) =>
    switch (mail?.sentAt(line.level)?.state) {
      ReminderMailState.accepted || ReminderMailState.delivered =>
        QueuedEmail.sent,
      ReminderMailState.pending || ReminderMailState.unconfirmed =>
        QueuedEmail.toDecide,
      ReminderMailState.refused => QueuedEmail.refused,
      ReminderMailState.notDelivered || null => QueuedEmail.none,
    };

/// A customer to check before anyone chases them: money of theirs is held
/// unassigned (the predicate of Payments to match).
typedef CheckFirstCustomer = ({String customerId, String customerName});

/// The queue and what has been done in it. Immutable: each result gives a
/// new queue.
@immutable
class ReminderQueue {
  const ReminderQueue(
    this.lines, [
    this.handled = const {},
    this.checkFirst = const [],
    this.email = const {},
  ]);

  /// invoice id -> what the server recorded for its e-mail at its level
  /// (#3673); an absent id is [QueuedEmail.none].
  final Map<String, QueuedEmail> email;

  QueuedEmail emailOf(QueuedReminder line) =>
      email[line.invoiceId] ?? QueuedEmail.none;

  /// #3614 — this queue narrowed to the invoices [ids] a person selected:
  /// their lines, and "check first" only for the customers they name
  /// ([customers]). The selection stays the scope while the reads change.
  ReminderQueue only(Set<String> ids, {required Set<String> customers}) =>
      ReminderQueue(
        [
          for (final l in lines)
            if (ids.contains(l.invoiceId)) l,
        ],
        handled,
        [
          for (final c in checkFirst)
            if (customers.contains(c.customerId)) c,
        ],
        email,
      );

  /// This queue with the server's e-mail rows read again.
  ReminderQueue withEmail(Map<String, QueuedEmail> email) =>
      ReminderQueue(lines, handled, checkFirst, email);

  /// What the result page lists as e-mailed.
  List<QueuedReminder> get emailed => [
    for (final l in lines)
      if (emailOf(l) == QueuedEmail.sent) l,
  ];

  /// What it lists as an e-mail to decide.
  List<QueuedReminder> get toDecide => [
    for (final l in lines)
      if (emailOf(l) == QueuedEmail.toDecide) l,
  ];

  final List<QueuedReminder> lines;

  /// Customers whose reminder is due but who hold money received and not
  /// assigned: not chased, listed FIRST to be checked (their payment matched).
  final List<CheckFirstCustomer> checkFirst;

  /// invoice id -> what became of it in this sitting.
  final Map<String, ReminderHandled> handled;

  /// The lines of [level], most late first (the queue's own order).
  List<QueuedReminder> ofLevel(int level) => [
    for (final l in lines)
      if (l.level == level) l,
  ];

  /// The levels present, lowest first.
  List<int> get levels => ({for (final l in lines) l.level}.toList()..sort());

  /// Whether [line] left the device (recorded or not), or by e-mail (or may
  /// have, until a person decides): never shared or e-mailed again.
  bool hasLeft(QueuedReminder line) =>
      switch (handled[line.invoiceId]) {
        ReminderHandled.shared || ReminderHandled.sharedNotRecorded => true,
        _ => false,
      } ||
      switch (emailOf(line)) {
        QueuedEmail.sent || QueuedEmail.toDecide => true,
        QueuedEmail.none || QueuedEmail.refused => false,
      };

  /// Still to share: not shared yet (a dismissed or failed line stays).
  List<QueuedReminder> get remaining => [
    for (final l in lines)
      if (!hasLeft(l)) l,
  ];

  /// The line "Share the next one" shares: the first not tried yet; when
  /// every line was tried, the first one not shared (a dismissed line is
  /// offered again, never skipped for good).
  QueuedReminder? get next {
    final fresh = [
      for (final l in lines)
        if (!handled.containsKey(l.invoiceId)) l,
    ];
    if (fresh.isNotEmpty) return fresh.first;
    return remaining.firstOrNull;
  }

  List<QueuedReminder> _where(ReminderHandled h) => [
    for (final l in lines)
      if (handled[l.invoiceId] == h) l,
  ];

  /// What the result page lists as shared.
  List<QueuedReminder> get shared => _where(ReminderHandled.shared);

  /// What it lists as not done: shared, but its level is not recorded yet,
  /// with Record (never a second share).
  List<QueuedReminder> get unrecorded =>
      _where(ReminderHandled.sharedNotRecorded);

  bool get isEmpty => lines.isEmpty;
  bool get isDone => lines.isNotEmpty && remaining.isEmpty;

  ReminderQueue withResult(String invoiceId, ReminderHandled result) =>
      ReminderQueue(lines, {...handled, invoiceId: result}, checkFirst, email);

  /// This queue drawn again as [fresh] says (the reads changed): its lines
  /// and "check first" are [fresh]'s, and a line that already left the
  /// device stays, with what became of it. A line [fresh] no longer has (a
  /// customer now known to hold money) is gone, so it cannot be shared.
  ReminderQueue refreshedBy(ReminderQueue fresh) {
    final left = [
      for (final l in lines)
        if (hasLeft(l)) l,
    ];
    final ids = {for (final l in left) l.invoiceId};
    return ReminderQueue(
      [
        ...left,
        for (final l in fresh.lines)
          if (!ids.contains(l.invoiceId)) l,
      ],
      handled,
      fresh.checkFirst,
      email,
    );
  }
}

/// The queue of [invoices] on [today]: only in [ReminderMode.byHand],
/// exactly the invoices the "To do" entry counts (`todoKindOf` is
/// [TodoKind.shareReminders]: a rejected e-invoice or a payment to confirm
/// comes first and is not shared), grouped by their level (lowest first),
/// the most late first inside a level, then the biggest amount.
///
/// [holdsUnassigned] are the customers who hold money received and not
/// assigned (`holdsUnassignedMoney`, the one predicate Payments to match also
/// uses): they are not chased; those with a reminder due are listed first as
/// [CheckFirstCustomer]s.
ReminderQueue reminderQueueOf(
  Iterable<Receivable> invoices,
  DateTime today,
  ReminderMode mode, {
  Set<String> holdsUnassigned = const {},
}) {
  final checkFirst = <String, CheckFirstCustomer>{
    for (final r in invoices)
      if (holdsUnassigned.contains(r.customerId) &&
          todoKindOf(r, mode) == TodoKind.shareReminders)
        r.customerId: (customerId: r.customerId, customerName: r.customerName),
  }.values.toList()..sort((a, b) => a.customerName.compareTo(b.customerName));
  final lines =
      [
        for (final r in invoices)
          if (todoKindOf(r, mode, holdsUnassigned: holdsUnassigned) ==
              TodoKind.shareReminders)
            QueuedReminder(r, r.reminderDueLevel!),
      ]..sort((a, b) {
        final level = a.level.compareTo(b.level);
        if (level != 0) return level;
        final late = (a.receivable.daysToDue(today) ?? 0).compareTo(
          b.receivable.daysToDue(today) ?? 0,
        );
        if (late != 0) return late;
        return b.receivable.openMinor.compareTo(a.receivable.openMinor);
      });
  return ReminderQueue(lines, const {}, checkFirst);
}

/// The letter of one reminder: built by the screen from the existing
/// reminder document (the same one the old "Send a reminder" shared).
typedef ReminderLetter = ({Uint8List bytes, String fileName, String message});

/// Shares [line] and records its level if it left; what became of it. A
/// share that left but whose record failed is
/// [ReminderHandled.sharedNotRecorded], never "could not be shared": it must
/// not be shared twice.
Future<ReminderHandled> shareQueuedReminder({
  required QueuedReminder line,
  required InvoiceCommands repository,
  required FileSharer share,
  required ReminderLetter letter,
}) async {
  var left = false;
  Future<FileShareOutcome> tracked({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? text,
  }) async {
    final outcome = await share(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      text: text,
    );
    left = outcome != FileShareOutcome.dismissed;
    return outcome;
  }

  try {
    final outcome = await sendReminder(
      repository: repository,
      share: tracked,
      invoiceId: line.invoiceId,
      level: line.level,
      bytes: letter.bytes,
      fileName: letter.fileName,
      message: letter.message,
    );
    return outcome is ReminderNotSent
        ? ReminderHandled.notRecorded
        : ReminderHandled.shared;
  } on Object {
    return left ? ReminderHandled.sharedNotRecorded : ReminderHandled.failed;
  }
}

/// Records the level of a reminder that already left ([line] is
/// [ReminderHandled.sharedNotRecorded]): the record only, never a second
/// share.
Future<ReminderHandled> recordQueuedReminder({
  required QueuedReminder line,
  required InvoiceCommands repository,
}) async {
  try {
    await repository.remindInvoice(line.invoiceId);
    return ReminderHandled.shared;
  } on Object {
    return ReminderHandled.sharedNotRecorded;
  }
}

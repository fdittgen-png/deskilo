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
import 'receivables.dart';
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

  /// The record or the share failed: nothing is known to have left.
  failed,
}

/// The queue and what has been done in it. Immutable: each result gives a
/// new queue.
@immutable
class ReminderQueue {
  const ReminderQueue(this.lines, [this.handled = const {}]);

  final List<QueuedReminder> lines;

  /// invoice id -> what became of it in this sitting.
  final Map<String, ReminderHandled> handled;

  /// The lines of [level], most late first (the queue's own order).
  List<QueuedReminder> ofLevel(int level) => [
    for (final l in lines)
      if (l.level == level) l,
  ];

  /// The levels present, lowest first.
  List<int> get levels => ({for (final l in lines) l.level}.toList()..sort());

  /// Still to share: not shared yet (a dismissed or failed line stays).
  List<QueuedReminder> get remaining => [
    for (final l in lines)
      if (handled[l.invoiceId] != ReminderHandled.shared) l,
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

  /// What it lists as "nothing was recorded".
  List<QueuedReminder> get notRecorded => _where(ReminderHandled.notRecorded);

  /// What it lists as not done, with a retry for those only.
  List<QueuedReminder> get failed => _where(ReminderHandled.failed);

  bool get isEmpty => lines.isEmpty;
  bool get isDone => lines.isNotEmpty && remaining.isEmpty;

  ReminderQueue withResult(String invoiceId, ReminderHandled result) =>
      ReminderQueue(lines, {...handled, invoiceId: result});
}

/// The queue of [invoices] on [today]: only in [ReminderMode.byHand], the
/// ones [reminderToShare] says are due, grouped by their level (lowest
/// first), the most late first inside a level, then the biggest amount.
ReminderQueue reminderQueueOf(
  Iterable<Receivable> invoices,
  DateTime today,
  ReminderMode mode,
) {
  final lines =
      [
        for (final r in invoices)
          if (reminderToShare(r, mode)) QueuedReminder(r, r.reminderDueLevel!),
      ]..sort((a, b) {
        final level = a.level.compareTo(b.level);
        if (level != 0) return level;
        final late = (a.receivable.daysToDue(today) ?? 0).compareTo(
          b.receivable.daysToDue(today) ?? 0,
        );
        if (late != 0) return late;
        return b.receivable.openMinor.compareTo(a.receivable.openMinor);
      });
  return ReminderQueue(lines);
}

/// The letter of one reminder: built by the screen from the existing
/// reminder document (the same one the old "Send a reminder" shared).
typedef ReminderLetter = ({Uint8List bytes, String fileName, String message});

/// Shares [line] and records its level if it left; the queue with that
/// line's result. A failure of the share or of the record is [failed] and
/// never "shared".
Future<ReminderQueue> shareQueuedReminder({
  required ReminderQueue queue,
  required QueuedReminder line,
  required InvoiceCommands repository,
  required FileSharer share,
  required ReminderLetter letter,
}) async {
  try {
    final outcome = await sendReminder(
      repository: repository,
      share: share,
      invoiceId: line.invoiceId,
      level: line.level,
      bytes: letter.bytes,
      fileName: letter.fileName,
      message: letter.message,
    );
    return queue.withResult(
      line.invoiceId,
      outcome is ReminderNotSent
          ? ReminderHandled.notRecorded
          : ReminderHandled.shared,
    );
  } on Object {
    return queue.withResult(line.invoiceId, ReminderHandled.failed);
  }
}

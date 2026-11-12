// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-f — one line of the reminder queue: the customer, what is owed,
// how late, what became of it in this sitting, and its actions. #3673 —
// with reminders by e-mail on, the line also says what the server recorded
// for its e-mail (or why the customer cannot be e-mailed), offers "Send by
// e-mail" beside "Share", and the decision on an e-mail nobody confirmed.
// Moved out of reminder_queue_screen.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/kit/status_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/reminder_queue.dart';
import '../../domain/reminder_mail.dart';

/// What a line's buttons do.
typedef ReminderQueueLineActions = ({
  VoidCallback onPreview,
  VoidCallback onShare,
  VoidCallback onRecord,
  VoidCallback onEmail,
  void Function({required bool delivered}) onDecide,
});

class ReminderQueueLineView extends ConsumerWidget {
  const ReminderQueueLineView({
    super.key,
    required this.line,
    required this.queue,
    required this.today,
    required this.busy,
    required this.row,
    required this.mailText,
    required this.actions,
  });

  final QueuedReminder line;
  final ReminderQueue queue;

  /// The business's calendar day (how late the line is).
  final DateTime today;

  /// Another line is being handled: this one's buttons wait.
  final bool busy;

  /// The server's e-mail row of the line's invoice, null while e-mail is
  /// off or not read.
  final ReminderMailLine? row;

  /// What the line says about its e-mail, null for nothing.
  final String? mailText;

  final ReminderQueueLineActions actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = line.receivable;
    final money = ref.watch(appFormatProvider).moneyIn(r.currency);
    final days = -(r.daysToDue(today) ?? 0);
    final l10n = context.l10n;
    final handled = queue.handled[line.invoiceId];
    final left = handled == ReminderHandled.sharedNotRecorded;
    final email = queue.emailOf(line);
    return Padding(
      key: ValueKey('reminder-queue-line-${line.invoiceId}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.customerName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(money.formatMinor(r.openMinor)),
            ],
          ),
          Text(
            l10n.reminderQueueDetail(days, r.number),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          ..._statuses(context, l10n, handled: handled, left: left),
          // #3673 — the e-mail as the server recorded it, or why not.
          if (mailText case final text?)
            Text(text, key: ValueKey('reminder-queue-mail-${line.invoiceId}')),
          // #3673 — three actions do not fit a phone's line: they wrap.
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ..._actions(l10n, handled: handled, left: left, email: email),
            ],
          ),
        ],
      ),
    );
  }

  /// What became of the line in this sitting, when something did.
  List<Widget> _statuses(
    BuildContext context,
    AppLocalizations l10n, {
    required ReminderHandled? handled,
    required bool left,
  }) => [
    // A closed share is a notice, not an error: nothing went wrong.
    if (handled == ReminderHandled.notRecorded)
      Text(
        l10n.reminderQueueNotRecorded,
        key: ValueKey('reminder-queue-status-${line.invoiceId}'),
        style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
      ),
    if (left)
      Text(
        l10n.reminderQueueSharedNotRecorded,
        key: ValueKey('reminder-queue-status-${line.invoiceId}'),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    if (handled == ReminderHandled.failed)
      Text(
        l10n.reminderQueueFailed,
        key: ValueKey('reminder-queue-status-${line.invoiceId}'),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
  ];

  /// [onTap] while no other line is being handled.
  VoidCallback? _act(VoidCallback onTap) => busy ? null : onTap;

  /// The line's buttons: Preview, then the decision, Record, its state, or
  /// the ways out.
  List<Widget> _actions(
    AppLocalizations l10n, {
    required ReminderHandled? handled,
    required bool left,
    required QueuedEmail email,
  }) => [
    TextButton(
      key: ValueKey('reminder-queue-preview-${line.invoiceId}'),
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      onPressed: _act(actions.onPreview),
      child: Text(l10n.invoiceTemplatePreview),
    ),
    ...switch (email) {
      // An e-mail nobody confirmed: the person decides it.
      QueuedEmail.toDecide => _decision(l10n),
      // It already left: Record, never a second share.
      _ when left => [_record(l10n)],
      QueuedEmail.sent => [
        _chip('emailed', l10n.reminderQueueEmailed(row!.lastSend!.recipient)),
      ],
      _ when handled == ReminderHandled.shared => [
        _chip('shared', l10n.reminderQueueShared),
      ],
      _ => _waysOut(l10n),
    },
  ];

  List<Widget> _decision(AppLocalizations l10n) => [
    TextButton(
      key: ValueKey('reminder-queue-lost-${line.invoiceId}'),
      onPressed: _act(() => actions.onDecide(delivered: false)),
      child: Text(l10n.purchaseOrderSendLost),
    ),
    FilledButton.tonal(
      key: ValueKey('reminder-queue-arrived-${line.invoiceId}'),
      onPressed: _act(() => actions.onDecide(delivered: true)),
      child: Text(l10n.purchaseOrderSendArrived),
    ),
  ];

  Widget _record(AppLocalizations l10n) => FilledButton.tonal(
    key: ValueKey('reminder-queue-record-${line.invoiceId}'),
    style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
    onPressed: _act(actions.onRecord),
    child: Text(l10n.reminderQueueRecord),
  );

  Widget _chip(String what, String label) => StatusChip(
    key: ValueKey('reminder-queue-$what-${line.invoiceId}'),
    label: label,
    tone: StatusTone.ok,
  );

  /// Send by e-mail (when the customer can be e-mailed) and Share.
  List<Widget> _waysOut(AppLocalizations l10n) => [
    if (row?.target.available ?? false)
      TextButton(
        key: ValueKey('reminder-queue-email-${line.invoiceId}'),
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: _act(actions.onEmail),
        child: Text(l10n.purchaseOrderSendEmail),
      ),
    FilledButton.tonal(
      key: ValueKey('reminder-queue-share-${line.invoiceId}'),
      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      onPressed: _act(actions.onShare),
      child: Text(l10n.reminderQueueShare),
    ),
  ];
}

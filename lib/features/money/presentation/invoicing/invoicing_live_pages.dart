// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-f -- the pages the invoicing home opens over itself, on the
// CURRENT reads: the customer page and the reminder queue follow the
// invoices and the one answer of money received and not assigned as they
// change, so a page opened before that answer landed never offers a
// reminder the answer then forbids.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/time/clock.dart';
import '../../application/receivables.dart';
import '../../application/reminder_queue.dart';
import '../../providers/money_providers.dart';
import 'customer_page.dart';
import 'invoicing_reads.dart';
import 'reminder_queue_screen.dart';

/// What the live pages read now: the receivables (empty while not read),
/// the money not assigned (null while not known), the mode and the day.
typedef _Now = ({
  List<Receivable>? receivables,
  ({Set<String> holders, Map<String, int> Function(String) creditOf})? money,
  ReminderMode mode,
  DateTime today,
});

_Now _now(WidgetRef ref) {
  final receivables = ref.watch(invoicingReceivablesProvider);
  final known = unassignedMoneyKnown(ref.watch(unassignedMoneyProvider));
  // #3742 — the receivables wait for the rules: no page shows a reminder
  // state on the defaults.
  final rules = ref.watch(dunningRulesProvider).value;
  final dayOf = ref.watch(invoicingBusinessProvider).dayOf;
  return (
    receivables: receivables,
    money: known == null || receivables == null
        ? null
        : (holders: known.holdersAmong(receivables), creditOf: known.creditOf),
    mode: rules?.automatic ?? false // empty-ok: the receivables above are null until the rules are read
        ? ReminderMode.automatic
        : ReminderMode.byHand,
    today: dayOf(ref.watch(clockProvider).now()),
  );
}

/// The customer page on the current reads: while who holds money is not
/// known, its credit is "not read" and it offers no Remind.
class LiveCustomerPage extends ConsumerWidget {
  const LiveCustomerPage({
    super.key,
    required this.customerId,
    required this.onOpenInvoice,
    required this.onAction,
  });

  final String customerId;
  final ValueChanged<String> onOpenInvoice;
  final ValueChanged<InvoiceAction> onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = _now(ref);
    return CustomerPage(
      customerId: customerId,
      receivables: now.receivables ?? const [],
      today: now.today,
      mode: now.mode,
      credit: now.money?.creditOf(customerId),
      onOpenInvoice: onOpenInvoice,
      onAction: onAction,
    );
  }
}

/// The reminder queue on the current reads: drawn again whenever they
/// change; nothing is shared while who holds money is not known.
class LiveReminderQueue extends ConsumerWidget {
  const LiveReminderQueue({super.key, required this.onMatch});

  /// Opens Payments to match for a customer under "Check first".
  final ValueChanged<String> onMatch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = _now(ref);
    final money = now.money;
    return ReminderQueueScreen(
      queue: money == null
          ? null
          : reminderQueueOf(
              now.receivables!,
              now.today,
              now.mode,
              holdsUnassigned: money.holders,
            ),
      today: now.today,
      onMatch: onMatch,
    );
  }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3614 — a customer has an address of their own,
// `/invoices/customer/<id>`: beside the invoice list on a large window, a
// page of its own otherwise (list_detail_route.dart). The search opens a
// customer there. A customer the reader has no invoice of — one that does
// not exist, or that they may not read — is said in words.
//
// The customer's one action (remind, match, confirm) runs on the reads as
// they are when it is pressed, from the home's row and from the customer's
// page alike.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/navigation/list_detail_route.dart';
import '../../application/receivables.dart';
import '../../providers/money_providers.dart';
import '../invoice_actions.dart';
import 'invoicing_live_pages.dart';
import 'invoicing_reads.dart';
import 'payments_to_match_screen.dart';

/// The address of the invoice list; an open invoice is `/invoices/<id>`.
const String invoicesPath = '/invoices';

/// The address under which a customer opens: `/invoices/customer/<id>`.
const String customersPath = '/invoices/customer';

/// The oldest of [customerId]'s [receivables] that [action] concerns, by
/// due day; null when none does.
String? _oldestConcerned(
  List<Receivable> receivables,
  String customerId,
  InvoiceAction action,
  ReminderMode mode,
) {
  final bool Function(Receivable) holds = switch (action) {
    InvoiceAction.shareReminder => (r) => reminderToShare(r, mode),
    InvoiceAction.confirmPayment => (r) => r.paymentDeclared,
    _ => (r) => r.paymentToMatch,
  };
  final theirs = [
    for (final r in receivables)
      if (r.customerId == customerId && holds(r)) r,
  ]..sort((a, b) => (a.dueOn ?? a.issuedOn).compareTo(b.dueOn ?? b.issuedOn));
  return theirs.firstOrNull?.invoiceId;
}

/// What a customer's controls open, on the reads as they are when pressed.
class CustomerActions {
  const CustomerActions(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  /// The payments [customerId] made that no invoice has taken, each with the
  /// open invoices of the business's currency it could settle; full screen,
  /// with its own messenger.
  Future<void> paymentsToMatch(String customerId) => showDialog<void>(
    context: context,
    builder: (_) => Dialog.fullscreen(
      child: ScaffoldMessenger(
        child: PaymentsToMatchScreen(
          currency: ref.read(invoicingBusinessProvider).currency,
          customerId: customerId,
        ),
      ),
    ),
  );

  /// Runs [customerId]'s [action] on their oldest invoice it concerns.
  /// Nobody is reminded while who holds money is not known; money held
  /// unassigned is matched from the payments, never by reminding.
  Future<void> run(String customerId, InvoiceAction action) async {
    final receivables = ref.read(invoicingReceivablesProvider);
    if (receivables == null) return;
    final money = unassignedMoneyKnown(ref.read(unassignedMoneyProvider));
    if (action == InvoiceAction.shareReminder && money == null) return;
    final holders = money?.holdersAmong(receivables) ?? const <String>{};
    if (action == InvoiceAction.match && holders.contains(customerId)) {
      await paymentsToMatch(customerId);
      return;
    }
    final rules = ref.read(dunningRulesProvider).value;
    final mode = rules != null && rules.automatic
        ? ReminderMode.automatic
        : ReminderMode.byHand;
    final id = _oldestConcerned(receivables, customerId, action, mode);
    final invoices = ref.read(invoicesProvider).value ?? const []; // empty-ok: the receivables above were read from these invoices
    final invoice = invoices.where((i) => i.id == id).firstOrNull;
    if (invoice == null || !context.mounted) return;
    switch (action) {
      case InvoiceAction.shareReminder:
        await remindInvoice(context, ref, invoice);
      case InvoiceAction.match:
        await matchInvoiceToPayment(context, ref, invoice);
      case _:
        // Confirm or Not received is decided on the invoice.
        openRecord(context, invoicesPath, invoice.id);
    }
  }
}

/// The customer [customerId] at their address, on the current reads.
class CustomerRecord extends ConsumerWidget {
  const CustomerRecord({super.key, required this.customerId, this.onClose});

  final String customerId;

  /// Set when the customer stands beside the list: its close button.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receivables = ref.watch(invoicingReceivablesProvider);
    final known =
        receivables == null ||
        receivables.any((r) => r.customerId == customerId);
    if (!known) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: onClose == null,
          actions: [
            if (onClose case final close?)
              CloseButton(
                key: const ValueKey('customer-page-close'),
                onPressed: close,
              ),
          ],
        ),
        body: Center(
          child: Text(
            context.l10n.searchRecordUnreadable,
            key: const ValueKey('search-record-unreadable'),
          ),
        ),
      );
    }
    return LiveCustomerPage(
      customerId: customerId,
      onClose: onClose,
      onOpenInvoice: (id) => openRecord(context, invoicesPath, id),
      onAction: (action) =>
          CustomerActions(context, ref).run(customerId, action),
    );
  }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — one open-invoice action as the hub draws it: its key, icon,
// words and callback. The classic list and the journey card share it,
// so an action reads the same on both.
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/open_invoice_rows.dart';
import 'open_invoice_card.dart';

/// How [act] looks and what it calls for the invoice [entry].
class OpenInvoiceActView {
  const OpenInvoiceActView(this.act, this.entry, this.actions);

  final OpenInvoiceAct act;
  final OpenInvoiceFacts entry;
  final OpenInvoiceActions actions;

  String get key {
    final id = entry.invoice.id;
    return switch (act) {
      OpenInvoiceAct.voidInvoice => 'invoice-void-open-$id',
      OpenInvoiceAct.proforma => 'invoice-proforma-$id',
      OpenInvoiceAct.remind => 'invoice-remind-$id',
      OpenInvoiceAct.match => 'invoice-match-$id',
      OpenInvoiceAct.writeoff => 'invoice-writeoff-$id',
      OpenInvoiceAct.writeoffPending => 'invoice-writeoff-pending-$id',
      OpenInvoiceAct.refund => 'invoice-refund-$id',
      OpenInvoiceAct.matchPending => 'invoice-match-pending-$id',
      OpenInvoiceAct.confirmInEvents => 'invoice-events-$id',
    };
  }

  IconData get icon => switch (act) {
    OpenInvoiceAct.voidInvoice => Icons.block_outlined,
    OpenInvoiceAct.proforma => Icons.description_outlined,
    OpenInvoiceAct.remind => Icons.notifications_outlined,
    OpenInvoiceAct.match => Icons.price_check_outlined,
    OpenInvoiceAct.writeoff => Icons.money_off_csred_outlined,
    OpenInvoiceAct.refund => Icons.currency_exchange,
    OpenInvoiceAct.writeoffPending ||
    OpenInvoiceAct.matchPending ||
    OpenInvoiceAct.confirmInEvents => Icons.how_to_vote_outlined,
  };

  String label(AppLocalizations l10n) => switch (act) {
    OpenInvoiceAct.voidInvoice => l10n.invoiceVoidAction,
    OpenInvoiceAct.proforma => l10n.invoiceProformaAction,
    OpenInvoiceAct.remind => l10n.invoiceRemindAction,
    OpenInvoiceAct.match => l10n.invoiceMatchAction,
    OpenInvoiceAct.writeoff => l10n.invoiceWriteoffButton,
    OpenInvoiceAct.refund => l10n.invoiceRefundButton,
    OpenInvoiceAct.writeoffPending ||
    OpenInvoiceAct.matchPending => l10n.invoiceMatchPendingBadge,
    OpenInvoiceAct.confirmInEvents => l10n.journeyPrimaryConfirmInEvents,
  };

  /// The callback the hub wired for [act]; null for the waiting chips.
  VoidCallback? get onPressed => switch (act) {
    OpenInvoiceAct.voidInvoice => () => actions.onVoid(entry),
    OpenInvoiceAct.proforma => () => actions.onProforma(entry),
    OpenInvoiceAct.remind => () => actions.onRemind(entry),
    OpenInvoiceAct.match => () => actions.onMatch(entry),
    OpenInvoiceAct.writeoff => () => actions.onWriteoff(entry),
    OpenInvoiceAct.refund => () => actions.onRefund(entry),
    OpenInvoiceAct.confirmInEvents => () => actions.onEvents(entry),
    OpenInvoiceAct.writeoffPending || OpenInvoiceAct.matchPending => null,
  };

  /// The chip of a waiting decision; null for an action with a button.
  Widget? chip(AppLocalizations l10n) => onPressed != null
      ? null
      : Chip(
          key: ValueKey(key),
          avatar: const Icon(Icons.how_to_vote_outlined, size: 18),
          label: Text(label(l10n)),
        );
}

// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:collection';

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/rate_format.dart';
import 'period_label.dart';

/// #3809 (part of #3657) — what a line says, printed from the facts the
/// server froze with it, in the document's language (`room_day`: the room
/// and its day; `cancelled`: what was taken back). Null for a kind or a
/// version this reader does not know, or values it cannot read: the caller
/// prints the frozen label instead, never an empty or invented text.
String? _lineFactsText(ReportStrings strings, Map<String, Object?>? facts) {
  if (facts == null || facts['version'] != 1) return null;
  final values = facts['values'];
  if (values is! Map) return null;
  switch (facts['kind']) {
    case 'room_day':
      final room = values['room'];
      final day = DateTime.tryParse('${values['day']}');
      if (room is! String || day == null) return null;
      final date = DateFormat.yMMMd(strings.dateLocale ?? strings.localeName)
          .format(day);
      return room.isEmpty ? date : '$room · $date';
    case 'cancelled':
      final of = values['of'];
      final what = _lineFactsText(
          strings, of is Map ? {for (final e in of.entries) '${e.key}': e.value} : null);
      return what == null ? null : strings.cancelledLine(what);
  }
  return null;
}

/// Localized wording for one DERIVED invoice position (0062): the kind
/// names the tracked source, the label carries its data. Reuses the
/// bill's own section labels so the invoice reads exactly like the
/// monthly bill it summarizes. Legacy 0060 free-form lines (empty kind)
/// and service/package lines render their stored text verbatim.
/// #870 — what the recurring position is CALLED.
///
/// A non-profit collects a member participation; only a commercial
/// space sells a subscription. The distinction is not cosmetic: on a
/// French association's invoice 'abonnement' reads as a commercial
/// supply and is exactly the wording that argues the association into
/// the VAT-liable trading sector. So the word follows the seller kind,
/// and every surface that names the position uses this one function.
///
/// #1000 — with [month] the position names the month it covers
/// ('Septembre 100 %'), so every invoice reads as the month it is for.
String subscriptionLabel(
  ReportStrings strings,
  int pct, {
  required bool association,
  String month = '',
}) {
  // The document's format locale, else its own language: a French document
  // that names no format locale still writes `100 %`, not an English `100%`.
  final rate = ratePercentText(
    pct,
    locale: strings.formatLocale ?? strings.localeName,
  );
  if (month.isNotEmpty) {
    return association
        ? strings.participationMonth(month, rate)
        : strings.subscriptionMonth(month, rate);
  }
  return association ? strings.participation(rate) : strings.subscription(rate);
}

String invoiceLineText(
  ReportStrings strings,
  InvoiceLine line, {
  bool association = false,
  /// #1000 — the invoice's period, so the recurring line names its month.
  String? period,
}) =>
    switch (line.kind) {
      'subscription' => subscriptionLabel(
          strings, int.tryParse(line.label) ?? 0,
          association: association,
          month: monthNameOf(strings.localeName, period)),
      'overage' =>
        strings.overage(line.quantity),
      'accessories' =>
        strings.accessorySupplements,
      'level' => strings.levelReservations,
      'office' => strings.officeReservations,
      'desk' => strings.deskReservations,
      'adjustment' => _lineFactsText(strings, line.text) ??
          (line.label.isNotEmpty ? line.label : strings.lineAdjustment),
      // 0063 — credits: payments and expense reimbursements carry
      // their ledger note behind the category label.
      'payment' => line.label.isEmpty
          ? (strings.categoryPayment)
          : '${strings.categoryPayment} · ${line.label}',
      'expense' => line.label.isEmpty
          ? (strings.categoryExpense)
          : '${strings.categoryExpense}'
              ' · ${line.label}',
      _ => _lineFactsText(strings, line.text) ?? line.label,
    };

/// Localized wording for one annex activity row (0064): the ledger
/// category label, with the entry's own note behind it.
String annexEntryText(ReportStrings strings, InvoiceDetailEntry entry) {
  final category = switch (entry.category) {
    'subscription' =>
      strings.categorySubscription,
    'overage' => strings.categoryOverage,
    'expense' => strings.categoryExpense,
    'payment' => strings.categoryPayment,
    'adjustment' => strings.categoryAdjustment,
    'service' => strings.categoryService,
    _ => entry.category,
  };
  final label = _lineFactsText(strings, entry.text) ?? entry.label;
  return label.isEmpty ? category : '$category · $label';
}

/// #3875 — the line of [invoice] worded by the seller kind the invoice was
/// issued under ([Invoice.sellerIsAssociationOr]); [liveAssociation] only
/// serves an invoice that froze none.
String invoiceLineTextFor(
  ReportStrings strings,
  Invoice invoice,
  InvoiceLine line, {
  required bool liveAssociation,
}) =>
    invoiceLineText(strings, line,
        association: invoice.sellerIsAssociationOr(liveAssociation),
        period: invoice.period);

/// #3875 — the same for an export of several invoices, whose writers ask
/// for the text of a line alone: each line is worded by ITS invoice (the
/// writers pass the invoice's own line objects); a line of none is worded
/// by [liveAssociation].
String Function(InvoiceLine line) invoiceLineTextOfBooks(
  ReportStrings strings,
  Iterable<Invoice> invoices, {
  required bool liveAssociation,
}) {
  final owner = HashMap<InvoiceLine, Invoice>.identity();
  for (final invoice in invoices) {
    for (final line in invoice.lines) {
      owner[line] = invoice;
    }
  }
  return (line) {
    final invoice = owner[line];
    return invoice == null
        ? invoiceLineText(strings, line, association: liveAssociation)
        : invoiceLineTextFor(strings, invoice, line,
            liveAssociation: liveAssociation);
  };
}

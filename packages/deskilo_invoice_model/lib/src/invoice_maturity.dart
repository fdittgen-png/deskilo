// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The maturity an invoice row embeds (`invoice_maturities`), read for Invoice.fromRow.

/// #1913 — the embedded `invoice_maturities` row (an object, on older servers a list of one or nothing).
Map<Object?, Object?>? maturityOf(Object? embedded) => switch (embedded) {
  final Map<Object?, Object?> map => map,
  final List<Object?> list when list.isNotEmpty && list.first is Map => list.first! as Map<Object?, Object?>,
  _ => null,
};

/// The day the invoice falls due, from the embedded row; null when it has none.
DateTime? maturityDueOn(Object? embedded) {
  final day = DateTime.tryParse('${maturityOf(embedded)?['due_on'] ?? ''}');
  return day == null ? null : DateTime(day.year, day.month, day.day);
}

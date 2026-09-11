// SPDX-License-Identifier: 0BSD
import 'package:intl/intl.dart';

import 'invoice.dart';

// #1061 — the period words with the locale as DATA, so the document
// builders (and the CLI) call them without a BuildContext. The context
// wrappers live in presentation/period_label.dart.

/// 'yyyy-MM' → the localized month name ('July 2026', 'juillet 2026').
String monthLabelOf(String? locale, String period) {
  final parts = period.split('-');
  if (parts.length < 2) return period;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null) return period;
  return DateFormat.yMMMM(locale).format(DateTime(year, month));
}

/// #1000 — the month's NAME alone ('Septembre', 'September'), for the
/// recurring position that must say which month it covers. '' for
/// anything that is not 'yyyy-MM'.
String monthNameOf(String? locale, String? period) {
  if (period == null) return '';
  final parts = period.split('-');
  if (parts.length < 2) return '';
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null) return '';
  final name = DateFormat.MMMM(locale).format(DateTime(year, month));
  return name.isEmpty ? '' : name[0].toUpperCase() + name.substring(1);
}

/// What an invoice COVERS, in words. The server stores the raw period as
/// the title ('2026-07'), which no user should ever read — so the period
/// wins and [Invoice.title] only serves legacy free-form invoices (0060).
String invoicePeriodLabelOf(String? locale, Invoice invoice) {
  final period = invoice.period;
  return period == null ? invoice.title : monthLabelOf(locale, period);
}

// SPDX-License-Identifier: 0BSD
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../domain/invoice.dart';

/// 'yyyy-MM' → the localized month name ('July 2026', 'juillet 2026').
/// Was copy-pasted in the archive and the hub; one home now.
String monthLabel(BuildContext context, String period) {
  final parts = period.split('-');
  if (parts.length < 2) return period;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null) return period;
  return DateFormat.yMMMM(
    Localizations.maybeLocaleOf(context)?.toString(),
  ).format(DateTime(year, month));
}

/// What an invoice COVERS, in words. The server stores the raw period as
/// the title ('2026-07'), which no user should ever read — so the period
/// wins and [Invoice.title] only serves legacy free-form invoices (0060).
String invoicePeriodLabel(BuildContext context, Invoice invoice) {
  final period = invoice.period;
  return period == null ? invoice.title : monthLabel(context, period);
}

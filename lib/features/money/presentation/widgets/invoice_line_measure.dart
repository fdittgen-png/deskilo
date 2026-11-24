// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4162 -- what the invoice sheet says under an issued commercial line: its
// exact quantity and unit at the price it was entered at, as the PDF prints
// them (`printedQuantity`, `printedUnitPrice`), never the legacy integer. A
// line this version cannot interpret shows its raw quantity, when it has one,
// and says that it is shown, not used.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import '../../../../l10n/app_localizations.dart';

/// The measure of [line] for the invoice sheet; null on a legacy line, which
/// shows only its label and amount as it always did.
String? invoiceLineMeasureText(AppLocalizations l10n, InvoiceLine line) {
  final v1 = line.exactFacts;
  if (v1 != null) {
    final price = '${v1.unitPrice.amount.text} ${v1.unitPrice.currency}';
    final base = v1.unitPrice.baseQuantity;
    return base.text == '1'
        ? l10n.commercialLineMeasure(line.printedQuantity, price)
        : l10n.commercialLineMeasurePer(
            line.printedQuantity,
            price,
            '${base.text} ${v1.unit.label}',
          );
  }
  final unsupported = line.unsupportedFacts;
  if (unsupported == null) return null;
  final raw = unsupported.rawQuantity;
  return raw == null
      ? l10n.commercialLineUnreadable
      : '$raw · ${l10n.commercialLineUnreadable}';
}

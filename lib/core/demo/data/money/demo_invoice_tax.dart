// SPDX-License-Identifier: AGPL-3.0-or-later
// Demo tax follows the configured rates and the rate frozen on a confirmed
// charge. Unwired test fakes retain their explicit, untaxed fixture behavior.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import '../money_repository.dart';

VatRate? demoDefaultVatRate(List<VatRate> rates) =>
    rates.where((r) => r.active && r.isDefault).firstOrNull;

({double percent, String category}) demoInvoiceLineTax(
  FakeMoneyRepository money,
  String period, {
  double? frozenPercent,
  bool credit = false,
}) {
  if (money.invoiceIdentity == null || credit) {
    return (percent: 0, category: '');
  }
  final rate = frozenPercent == null
      ? demoDefaultVatRate(money.vatRates)
      : money.vatRates
            .where((r) => r.active && r.percent == frozenPercent)
            .firstOrNull;
  final percent =
      frozenPercent ??
      (rate == null
          ? 0.0
          : vatPercentAt(
                  money.vatRates,
                  rate.id,
                  vatTaxPoint(period, money.clock()),
                ) ??
                rate.percent);
  return (
    percent: percent,
    category: rate?.category ?? (percent > 0 ? 'S' : 'O'),
  );
}

List<InvoiceVatTotal> demoInvoiceTaxTotals(List<InvoiceLine> lines) {
  final totals = <(double, String), ({int gross, int net})>{};
  for (final line in lines) {
    if (line.amountCents <= 0 && line.vatPercent == 0) continue;
    final key = (line.vatPercent, line.vatCategory);
    final before = totals[key] ?? (gross: 0, net: 0);
    totals[key] = (
      gross: before.gross + line.amountCents,
      net: before.net + vatSplit(line.amountCents, line.vatPercent).netCents,
    );
  }
  return [
    for (final entry in totals.entries)
      InvoiceVatTotal(
        percent: entry.key.$1,
        category: entry.key.$2,
        grossCents: entry.value.gross,
        netCents: entry.value.net,
        vatCents: entry.value.gross - entry.value.net,
      ),
  ];
}

// SPDX-License-Identifier: AGPL-3.0-or-later
import '../vat_form_terms.dart';
import '../vat_forms.dart';

final gbVat100Spec = VatFormSpec(
  country: 'GB',
  name: 'VAT100 (MTD)',
  validFrom: DateTime(2024),
  boxes: [
    VatBoxSpec(
      'Box 1',
      'VAT due on sales and other outputs',
      tax: [vatSales(categories: null)],
      taxKey: 'vatDueSales',
      always: true,
    ),
    const VatBoxSpec(
      'Box 2',
      'VAT due on acquisitions from EU member states',
      tax: [vatNothing],
      taxKey: 'vatDueAcquisitions',
      always: true,
    ),
    const VatBoxSpec(
      'Box 3',
      'Total VAT due',
      tax: [VatTerm.box('Box 1', tax: true), VatTerm.box('Box 2', tax: true)],
      taxKey: 'totalVatDue',
      always: true,
    ),
    VatBoxSpec(
      'Box 4',
      'VAT reclaimed on purchases and other inputs',
      tax: [vatInput()],
      taxKey: 'vatReclaimedCurrPeriod',
      always: true,
    ),
    const VatBoxSpec(
      'Box 5',
      'Net VAT to pay to HMRC or reclaim',
      tax: [
        VatTerm.box('Box 3', tax: true),
        VatTerm.box('Box 4', tax: true, factor: -1),
      ],
      taxKey: 'netVatDue',
      absolute: true,
      always: true,
    ),
    VatBoxSpec(
      'Box 6',
      'Total value of sales and all other outputs excluding VAT',
      base: [vatSales(categories: null)],
      baseKey: 'totalValueSalesExVAT',
      baseRounding: vatWholeDown,
      always: true,
    ),
    VatBoxSpec(
      'Box 7',
      'Total value of purchases and all other inputs excluding VAT',
      base: [vatInput()],
      baseKey: 'totalValuePurchasesExVAT',
      baseRounding: vatWholeDown,
      always: true,
    ),
    const VatBoxSpec(
      'Box 8',
      'Total value of supplies of goods to EU member states',
      base: [vatNothing],
      baseKey: 'totalValueGoodsSuppliedExVAT',
      always: true,
    ),
    const VatBoxSpec(
      'Box 9',
      'Total value of acquisitions of goods from EU member states',
      base: [vatNothing],
      baseKey: 'totalAcquisitionsExVAT',
      always: true,
    ),
  ],
);

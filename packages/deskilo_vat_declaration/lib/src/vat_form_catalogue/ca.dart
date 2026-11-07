// SPDX-License-Identifier: AGPL-3.0-or-later
import '../vat_form_terms.dart';
import '../vat_forms.dart';

/// #2361 — the federal taxes of a line (the QST is Revenu Québec's).
const _federal = {'GST', 'HST'};
const _qst = {'QST'};

final caGst34Spec = VatFormSpec(
  country: 'CA',
  name: 'GST/HST return (GST34)',
  validFrom: DateTime(2024),
  boxes: [
    VatBoxSpec(
      '101',
      'Sales and other revenue',
      base: [vatSales(categories: null)],
      baseKey: '101',
      baseRounding: vatWhole,
      always: true,
    ),
    VatBoxSpec(
      '103',
      'GST/HST collected or collectible',
      tax: [vatSales(correction: false, schemes: _federal)],
      taxKey: '103',
      always: true,
    ),
    VatBoxSpec(
      '104',
      'Adjustments to be added to the net tax',
      tax: [vatSales(correction: true, vatSign: 1, schemes: _federal)],
      taxKey: '104',
    ),
    const VatBoxSpec(
      '105',
      'Total GST/HST and adjustments for the period',
      tax: [VatTerm.box('103', tax: true), VatTerm.box('104', tax: true)],
      taxKey: '105',
      always: true,
    ),
    VatBoxSpec(
      '106',
      'Input tax credits (ITCs) for the current period',
      tax: [vatInput(schemes: _federal)],
      taxKey: '106',
    ),
    VatBoxSpec(
      '107',
      'Adjustments to be deducted when determining the net tax',
      tax: [vatSales(correction: true, vatSign: -1, factor: -1, schemes: _federal)],
      taxKey: '107',
    ),
    const VatBoxSpec(
      '108',
      'Total ITCs and adjustments',
      tax: [VatTerm.box('106', tax: true), VatTerm.box('107', tax: true)],
      taxKey: '108',
      always: true,
    ),
    const VatBoxSpec(
      '109',
      'Net tax',
      tax: [
        VatTerm.box('105', tax: true),
        VatTerm.box('108', tax: true, factor: -1),
      ],
      taxKey: '109',
      always: true,
    ),
  ],
);

/// #2361 — the QST part of Revenu Québec's FPZ-500 (the GST/HST part is the
/// same figures as [caGst34Spec], lines 101–109): 203 QST collected, 204
/// adjustments added, 205 their total, 206 input tax refunds, 207
/// adjustments deducted, 208 their total, 209 net QST. Numbered as the GST
/// lines are, 100 higher; checked against the guides' wording, not against
/// the current form — filing is the owner's.
final caFpz500QstSpec = VatFormSpec(
  country: 'CA-QC',
  name: 'FPZ-500 (QST)',
  validFrom: DateTime(2024),
  boxes: [
    VatBoxSpec(
      '203',
      'QST collected or collectible',
      tax: [vatSales(correction: false, schemes: _qst)],
      taxKey: '203',
      always: true,
    ),
    VatBoxSpec(
      '204',
      'Adjustments to be added to the net QST',
      tax: [vatSales(correction: true, vatSign: 1, schemes: _qst)],
      taxKey: '204',
    ),
    const VatBoxSpec(
      '205',
      'Total QST and adjustments for the period',
      tax: [VatTerm.box('203', tax: true), VatTerm.box('204', tax: true)],
      taxKey: '205',
      always: true,
    ),
    VatBoxSpec(
      '206',
      'Input tax refunds (ITRs) for the current period',
      tax: [vatInput(schemes: _qst)],
      taxKey: '206',
    ),
    VatBoxSpec(
      '207',
      'Adjustments to be deducted when determining the net QST',
      tax: [vatSales(correction: true, vatSign: -1, factor: -1, schemes: _qst)],
      taxKey: '207',
    ),
    const VatBoxSpec(
      '208',
      'Total ITRs and adjustments',
      tax: [VatTerm.box('206', tax: true), VatTerm.box('207', tax: true)],
      taxKey: '208',
      always: true,
    ),
    const VatBoxSpec(
      '209',
      'Net QST',
      tax: [
        VatTerm.box('205', tax: true),
        VatTerm.box('208', tax: true, factor: -1),
      ],
      taxKey: '209',
      always: true,
    ),
  ],
);

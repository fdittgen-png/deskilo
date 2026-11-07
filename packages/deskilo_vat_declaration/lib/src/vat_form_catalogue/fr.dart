// SPDX-License-Identifier: AGPL-3.0-or-later
import '../vat_form_terms.dart';
import '../vat_forms.dart';

/// The period's own sales plus the corrections in the Treasury's favour (FR:
/// they add to their rate line). A rated box names its `form_box` row, which
/// says which fiscal groups the line takes.
List<VatTerm> _frRate() => [
  vatSales(correction: false),
  vatSales(correction: true, vatSign: 1),
];

final frCa3Spec = VatFormSpec(
  country: 'FR',
  name: 'CA3 (3310-CA3-SD)',
  validFrom: DateTime(2024),
  boxes: [
    VatBoxSpec(
      'A1',
      'Ventes, prestations de services',
      base: [..._frRate()],
      baseKey: '0979',
      baseRounding: vatWhole,
    ),
    VatBoxSpec(
      'E1',
      'Exportations hors UE',
      base: [
        vatSales(categories: {'G'}),
      ],
      baseKey: '0032',
      baseRounding: vatWhole,
    ),
    VatBoxSpec(
      'E2',
      'Autres opérations non imposables',
      base: [
        vatSales(categories: {'AE', 'E', 'Z', 'O'}),
      ],
      baseKey: '0033',
      baseRounding: vatWhole,
    ),
    VatBoxSpec(
      '08',
      '',
      formBox: 'ca3/08',
      base: _frRate(),
      tax: _frRate(),
      baseKey: '0207',
      taxKey: '0207',
      baseRounding: vatWhole,
      taxRounding: vatWhole,
    ),
    VatBoxSpec(
      '09',
      '',
      formBox: 'ca3/09',
      base: _frRate(),
      tax: _frRate(),
      baseKey: '0105',
      taxKey: '0105',
      baseRounding: vatWhole,
      taxRounding: vatWhole,
    ),
    VatBoxSpec(
      '9B',
      '',
      formBox: 'ca3/9B',
      base: _frRate(),
      tax: _frRate(),
      baseKey: '0151',
      taxKey: '0151',
      baseRounding: vatWhole,
      taxRounding: vatWhole,
    ),
    VatBoxSpec(
      '11',
      '',
      formBox: 'ca3/11',
      base: _frRate(),
      tax: _frRate(),
      baseKey: '0100',
      taxKey: '0100',
      baseRounding: vatWhole,
      taxRounding: vatWhole,
    ),
    VatBoxSpec(
      '14',
      '',
      formBox: 'ca3/14',
      base: _frRate(),
      tax: _frRate(),
      baseKey: '0950',
      taxKey: '0950',
      baseRounding: vatWhole,
      taxRounding: vatWhole,
    ),
    VatBoxSpec(
      '15',
      'TVA antérieurement déduite à reverser',
      tax: [vatInput(correction: true, vatSign: -1, factor: -1)],
      taxKey: '0600',
      taxRounding: vatWhole,
    ),
    const VatBoxSpec(
      '16',
      'Total de la TVA brute due',
      tax: [
        VatTerm.box('08', tax: true),
        VatTerm.box('09', tax: true),
        VatTerm.box('9B', tax: true),
        VatTerm.box('11', tax: true),
        VatTerm.box('14', tax: true),
        VatTerm.box('15', tax: true),
      ],
      always: true,
    ),
    VatBoxSpec(
      '19',
      'Biens constituant des immobilisations',
      tax: [
        vatInput(categories: vatAsset, correction: false),
        vatInput(categories: vatAsset, correction: true, vatSign: 1),
      ],
      taxKey: '0703',
      taxRounding: vatWhole,
    ),
    VatBoxSpec(
      '20',
      'Autres biens et services',
      tax: [
        vatInput(categories: vatTaxable, correction: false),
        vatInput(categories: vatTaxable, correction: true, vatSign: 1),
      ],
      taxKey: '0702',
      taxRounding: vatWhole,
    ),
    VatBoxSpec(
      '21',
      'Autre TVA à déduire',
      tax: [
        vatSales(categories: null, correction: true, vatSign: -1, factor: -1),
      ],
      taxKey: '0059',
      taxRounding: vatWhole,
    ),
    const VatBoxSpec(
      '23',
      'Total de la TVA déductible',
      tax: [
        VatTerm.box('19', tax: true),
        VatTerm.box('20', tax: true),
        VatTerm.box('21', tax: true),
      ],
      always: true,
    ),
    const VatBoxSpec(
      '25',
      'Crédit de TVA',
      tax: [
        VatTerm.box('23', tax: true),
        VatTerm.box('16', tax: true, factor: -1),
      ],
      taxKey: '0705',
      clampAtZero: true,
    ),
    const VatBoxSpec(
      '28',
      'TVA nette due',
      tax: [
        VatTerm.box('16', tax: true),
        VatTerm.box('23', tax: true, factor: -1),
      ],
      taxKey: '8901',
      clampAtZero: true,
      always: true,
    ),
  ],
);

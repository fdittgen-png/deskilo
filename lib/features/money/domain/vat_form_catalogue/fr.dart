// SPDX-License-Identifier: AGPL-3.0-or-later
part of '../vat_form_catalogue.dart';

/// The period's own sales at [rates] plus the corrections in the
/// Treasury's favour (FR: they add to their rate line).
List<VatTerm> _frRate({Set<double>? rates, Set<double>? otherRatesThan}) => [
  _sales(rates: rates, otherRatesThan: otherRatesThan, correction: false),
  _sales(
    rates: rates,
    otherRatesThan: otherRatesThan,
    correction: true,
    vatSign: 1,
  ),
];

final _frNamed = <double>{20, 10, 5.5, 2.1};

final _ca3 = VatFormSpec(
  country: 'FR',
  name: 'CA3 (3310-CA3-SD)',
  validFrom: DateTime(2024),
  boxes: [
    VatBoxSpec(
      'A1',
      'Ventes, prestations de services',
      base: [..._frRate()],
      baseKey: '0979',
      baseRounding: _w,
    ),
    VatBoxSpec(
      'E1',
      'Exportations hors UE',
      base: [
        _sales(categories: {'G'}),
      ],
      baseKey: '0032',
      baseRounding: _w,
    ),
    VatBoxSpec(
      'E2',
      'Autres opérations non imposables',
      base: [
        _sales(categories: {'AE', 'E', 'Z', 'O'}),
      ],
      baseKey: '0033',
      baseRounding: _w,
    ),
    VatBoxSpec(
      '08',
      'Taux normal 20 %',
      base: _frRate(rates: {20}),
      tax: _frRate(rates: {20}),
      baseKey: '0207',
      taxKey: '0207',
      baseRounding: _w,
      taxRounding: _w,
    ),
    VatBoxSpec(
      '09',
      'Taux réduit 5,5 %',
      base: _frRate(rates: {5.5}),
      tax: _frRate(rates: {5.5}),
      baseKey: '0105',
      taxKey: '0105',
      baseRounding: _w,
      taxRounding: _w,
    ),
    VatBoxSpec(
      '9B',
      'Taux réduit 10 %',
      base: _frRate(rates: {10}),
      tax: _frRate(rates: {10}),
      baseKey: '0151',
      taxKey: '0151',
      baseRounding: _w,
      taxRounding: _w,
    ),
    VatBoxSpec(
      '11',
      'Taux particulier 2,1 %',
      base: _frRate(rates: {2.1}),
      tax: _frRate(rates: {2.1}),
      baseKey: '0100',
      taxKey: '0100',
      baseRounding: _w,
      taxRounding: _w,
    ),
    VatBoxSpec(
      '14',
      'Opérations imposables à un autre taux',
      base: _frRate(otherRatesThan: _frNamed),
      tax: _frRate(otherRatesThan: _frNamed),
      baseKey: '0950',
      taxKey: '0950',
      baseRounding: _w,
      taxRounding: _w,
    ),
    VatBoxSpec(
      '15',
      'TVA antérieurement déduite à reverser',
      tax: [_input(correction: true, vatSign: -1, factor: -1)],
      taxKey: '0600',
      taxRounding: _w,
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
        _input(categories: _asset, correction: false),
        _input(categories: _asset, correction: true, vatSign: 1),
      ],
      taxKey: '0703',
      taxRounding: _w,
    ),
    VatBoxSpec(
      '20',
      'Autres biens et services',
      tax: [
        _input(categories: _taxable, correction: false),
        _input(categories: _taxable, correction: true, vatSign: 1),
      ],
      taxKey: '0702',
      taxRounding: _w,
    ),
    VatBoxSpec(
      '21',
      'Autre TVA à déduire',
      tax: [
        _sales(categories: null, correction: true, vatSign: -1, factor: -1),
      ],
      taxKey: '0059',
      taxRounding: _w,
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

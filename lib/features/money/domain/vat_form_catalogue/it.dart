// SPDX-License-Identifier: AGPL-3.0-or-later
part of '../vat_form_catalogue.dart';

final _lipe = VatFormSpec(
  country: 'IT',
  name: 'Liquidazione periodica IVA (quadro VP)',
  validFrom: DateTime(2024),
  boxes: [
    VatBoxSpec(
      'VP2',
      'Totale operazioni attive (al netto dell\'IVA)',
      base: [_sales(categories: null)],
      baseKey: 'VP2',
      always: true,
    ),
    VatBoxSpec(
      'VP3',
      'Totale operazioni passive (al netto dell\'IVA)',
      base: [_input()],
      baseKey: 'VP3',
      always: true,
    ),
    VatBoxSpec(
      'VP4',
      'IVA esigibile',
      tax: [_sales()],
      taxKey: 'VP4',
      always: true,
    ),
    VatBoxSpec(
      'VP5',
      'IVA detratta',
      tax: [_input()],
      taxKey: 'VP5',
      always: true,
    ),
    const VatBoxSpec(
      'VP6 col. 1',
      'IVA dovuta',
      tax: [
        VatTerm.box('VP4', tax: true),
        VatTerm.box('VP5', tax: true, factor: -1),
      ],
      taxKey: 'VP6_1',
      clampAtZero: true,
      always: true,
    ),
    const VatBoxSpec(
      'VP6 col. 2',
      'IVA a credito',
      tax: [
        VatTerm.box('VP5', tax: true),
        VatTerm.box('VP4', tax: true, factor: -1),
      ],
      taxKey: 'VP6_2',
      clampAtZero: true,
    ),
  ],
);

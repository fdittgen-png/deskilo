// SPDX-License-Identifier: AGPL-3.0-or-later
import '../vat_form_terms.dart';
import '../vat_forms.dart';

final itLipeSpec = VatFormSpec(
  country: 'IT',
  name: 'Liquidazione periodica IVA (quadro VP)',
  validFrom: DateTime(2024),
  boxes: [
    VatBoxSpec(
      'VP2',
      'Totale operazioni attive (al netto dell\'IVA)',
      base: [vatSales(categories: null)],
      baseKey: 'VP2',
      always: true,
    ),
    VatBoxSpec(
      'VP3',
      'Totale operazioni passive (al netto dell\'IVA)',
      base: [vatInput()],
      baseKey: 'VP3',
      always: true,
    ),
    VatBoxSpec(
      'VP4',
      'IVA esigibile',
      tax: [vatSales()],
      taxKey: 'VP4',
      always: true,
    ),
    VatBoxSpec(
      'VP5',
      'IVA detratta',
      tax: [vatInput()],
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

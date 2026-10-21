// SPDX-License-Identifier: AGPL-3.0-or-later
import '../vat_form_terms.dart';
import '../vat_forms.dart';

final deUstvaSpec = VatFormSpec(
  country: 'DE',
  name: 'UStVA',
  validFrom: DateTime(2024),
  boxes: [
    VatBoxSpec(
      'Kz 81',
      '',
      formBox: 'ustva/Kz 81',
      base: [vatSales()],
      tax: [vatSales()],
      baseKey: 'Kz81',
      baseRounding: vatWholeDown,
    ),
    VatBoxSpec(
      'Kz 86',
      '',
      formBox: 'ustva/Kz 86',
      base: [vatSales()],
      tax: [vatSales()],
      baseKey: 'Kz86',
      baseRounding: vatWholeDown,
    ),
    VatBoxSpec(
      'Kz 35/36',
      '',
      formBox: 'ustva/Kz 35/36',
      base: [vatSales()],
      tax: [vatSales()],
      baseKey: 'Kz35',
      taxKey: 'Kz36',
      baseRounding: vatWholeDown,
    ),
    VatBoxSpec(
      'Kz 21',
      'Nicht steuerbare sonstige Leistungen (Leistungsort nicht im Inland)',
      base: [
        vatSales(categories: {'AE'}),
      ],
      baseKey: 'Kz21',
      baseRounding: vatWholeDown,
    ),
    VatBoxSpec(
      'Kz 45',
      'Übrige nicht steuerbare Umsätze (Leistungsort nicht im Inland)',
      base: [
        vatSales(categories: {'G', 'O'}),
      ],
      baseKey: 'Kz45',
      baseRounding: vatWholeDown,
    ),
    VatBoxSpec(
      'Kz 43',
      'Weitere steuerfreie Umsätze mit Vorsteuerabzug',
      base: [
        vatSales(categories: {'Z'}),
      ],
      baseKey: 'Kz43',
      baseRounding: vatWholeDown,
    ),
    VatBoxSpec(
      'Kz 48',
      'Steuerfreie Umsätze ohne Vorsteuerabzug',
      base: [
        vatSales(categories: {'E'}),
      ],
      baseKey: 'Kz48',
      baseRounding: vatWholeDown,
    ),
    VatBoxSpec(
      'Kz 66',
      'Vorsteuerbeträge aus Rechnungen von anderen Unternehmern',
      tax: [vatInput()],
      taxKey: 'Kz66',
    ),
    const VatBoxSpec(
      'Kz 83',
      'Verbleibende Umsatzsteuer-Vorauszahlung / Überschuss',
      tax: [
        VatTerm.box('Kz 81', tax: true),
        VatTerm.box('Kz 86', tax: true),
        VatTerm.box('Kz 35/36', tax: true),
        VatTerm.box('Kz 66', tax: true, factor: -1),
      ],
      taxKey: 'Kz83',
      always: true,
    ),
  ],
);

// SPDX-License-Identifier: AGPL-3.0-or-later
part of '../vat_form_catalogue.dart';

final _ustva = VatFormSpec(
  country: 'DE',
  name: 'UStVA',
  validFrom: DateTime(2024),
  boxes: [
    VatBoxSpec(
      'Kz 81',
      '',
      formBox: 'ustva/Kz 81',
      base: [_sales()],
      tax: [_sales()],
      baseKey: 'Kz81',
      baseRounding: _wd,
    ),
    VatBoxSpec(
      'Kz 86',
      '',
      formBox: 'ustva/Kz 86',
      base: [_sales()],
      tax: [_sales()],
      baseKey: 'Kz86',
      baseRounding: _wd,
    ),
    VatBoxSpec(
      'Kz 35/36',
      '',
      formBox: 'ustva/Kz 35/36',
      base: [_sales()],
      tax: [_sales()],
      baseKey: 'Kz35',
      taxKey: 'Kz36',
      baseRounding: _wd,
    ),
    VatBoxSpec(
      'Kz 21',
      'Nicht steuerbare sonstige Leistungen (Leistungsort nicht im Inland)',
      base: [
        _sales(categories: {'AE'}),
      ],
      baseKey: 'Kz21',
      baseRounding: _wd,
    ),
    VatBoxSpec(
      'Kz 45',
      'Übrige nicht steuerbare Umsätze (Leistungsort nicht im Inland)',
      base: [
        _sales(categories: {'G', 'O'}),
      ],
      baseKey: 'Kz45',
      baseRounding: _wd,
    ),
    VatBoxSpec(
      'Kz 43',
      'Weitere steuerfreie Umsätze mit Vorsteuerabzug',
      base: [
        _sales(categories: {'Z'}),
      ],
      baseKey: 'Kz43',
      baseRounding: _wd,
    ),
    VatBoxSpec(
      'Kz 48',
      'Steuerfreie Umsätze ohne Vorsteuerabzug',
      base: [
        _sales(categories: {'E'}),
      ],
      baseKey: 'Kz48',
      baseRounding: _wd,
    ),
    VatBoxSpec(
      'Kz 66',
      'Vorsteuerbeträge aus Rechnungen von anderen Unternehmern',
      tax: [_input()],
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

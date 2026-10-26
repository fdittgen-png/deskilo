// SPDX-License-Identifier: AGPL-3.0-or-later
import '../vat_form_terms.dart';
import '../vat_forms.dart';

// #2360 — the effective method, from the 2024 rates. Every amount to the
// centime: eCH-0217 (the ESTV's upload standard) has amounts with two
// decimals and computes `payableTax` from them without intermediate
// rounding. The rate lines are 303/313/343 since the rates of 2024
// (302/312/342 are the old rates' lines, for corrections).
// 205 is the part of 200 that is an exempt letting the seller opted to
// tax (art. 22), as each sales line states it; 383 the acquisition tax
// (art. 45) on the services an expense says were bought from abroad, its
// deductible share on 400/405 like any input tax.
// Not mapped, on purpose: 225 (transfer by notification), 235
// (reductions of consideration: a credit note nets in 200), 280
// (miscellaneous), 382 (the acquisition tax at the rates before 2024), 410
// (Einlageentsteuerung), 415/420 (corrections and reductions of input
// tax). The net-tax-rate method (Saldosteuersatz) is another form.
final chMwstSpec = VatFormSpec(
  country: 'CH',
  name: 'MWST-Abrechnung (effektive Methode)',
  validFrom: DateTime(2024),
  boxes: [
    VatBoxSpec(
      '200',
      'Total der vereinbarten bzw. vereinnahmten Entgelte',
      base: [vatSales(categories: null)],
      baseKey: '200',
      always: true,
    ),
    const VatBoxSpec(
      '205',
      '',
      formBox: 'mwst/205',
      base: [vatOpted],
      baseKey: '205',
    ),
    VatBoxSpec(
      '220',
      'Von der Steuer befreite Leistungen (Exporte)',
      base: [
        vatSales(categories: {'Z', 'G'}),
      ],
      baseKey: '220',
    ),
    VatBoxSpec(
      '221',
      'Leistungen im Ausland (Ort der Leistung im Ausland)',
      base: [
        vatSales(categories: {'AE', 'O'}),
      ],
      baseKey: '221',
    ),
    VatBoxSpec(
      '230',
      'Von der Steuer ausgenommene Leistungen',
      base: [
        vatSales(categories: {'E'}),
      ],
      baseKey: '230',
    ),
    const VatBoxSpec(
      '289',
      'Total Abzüge',
      base: [VatTerm.box('220'), VatTerm.box('221'), VatTerm.box('230')],
      baseKey: '289',
    ),
    const VatBoxSpec(
      '299',
      'Steuerbarer Gesamtumsatz',
      base: [VatTerm.box('200'), VatTerm.box('289', factor: -1)],
      baseKey: '299',
      always: true,
    ),
    VatBoxSpec(
      '303',
      '',
      formBox: 'mwst/303',
      base: [vatSales()],
      tax: [vatSales()],
      baseKey: '303',
      taxKey: '303',
    ),
    VatBoxSpec(
      '313',
      '',
      formBox: 'mwst/313',
      base: [vatSales()],
      tax: [vatSales()],
      baseKey: '313',
      taxKey: '313',
    ),
    VatBoxSpec(
      '343',
      '',
      formBox: 'mwst/343',
      base: [vatSales()],
      tax: [vatSales()],
      baseKey: '343',
      taxKey: '343',
    ),
    VatBoxSpec(
      '383',
      '',
      formBox: 'mwst/383',
      base: [vatSales(categories: vatAcquisition)],
      tax: [vatSales(categories: vatAcquisition)],
      baseKey: '383',
      taxKey: '383',
    ),
    VatBoxSpec(
      '399',
      'Total geschuldete Steuer',
      tax: [vatSales(), vatSales(categories: vatAcquisition)],
      taxKey: '399',
      always: true,
    ),
    VatBoxSpec(
      '400',
      'Vorsteuer auf Material- und Dienstleistungsaufwand',
      tax: [vatInput(categories: vatTaxable)],
      taxKey: '400',
    ),
    VatBoxSpec(
      '405',
      'Vorsteuer auf Investitionen und übrigem Betriebsaufwand',
      tax: [vatInput(categories: vatAsset)],
      taxKey: '405',
    ),
    const VatBoxSpec(
      '479',
      'Total Vorsteuer',
      tax: [VatTerm.box('400', tax: true), VatTerm.box('405', tax: true)],
      taxKey: '479',
      always: true,
    ),
    const VatBoxSpec(
      '500',
      'Zu bezahlender Betrag',
      tax: [
        VatTerm.box('399', tax: true),
        VatTerm.box('479', tax: true, factor: -1),
      ],
      taxKey: '500',
      clampAtZero: true,
      always: true,
    ),
    const VatBoxSpec(
      '510',
      'Guthaben der steuerpflichtigen Person',
      tax: [
        VatTerm.box('479', tax: true),
        VatTerm.box('399', tax: true, factor: -1),
      ],
      taxKey: '510',
      clampAtZero: true,
    ),
  ],
);

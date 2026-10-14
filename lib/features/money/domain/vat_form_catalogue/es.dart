// SPDX-License-Identifier: AGPL-3.0-or-later
part of '../vat_form_catalogue.dart';

final _modelo303 = VatFormSpec(
  country: 'ES',
  name: 'Modelo 303',
  validFrom: DateTime(2024),
  boxes: [
    VatBoxSpec(
      '01/03',
      '',
      formBox: 'modelo303/01/03',
      base: [_sales()],
      tax: [_sales()],
      baseKey: '01',
      taxKey: '03',
    ),
    VatBoxSpec(
      '04/06',
      '',
      formBox: 'modelo303/04/06',
      base: [_sales()],
      tax: [_sales()],
      baseKey: '04',
      taxKey: '06',
    ),
    VatBoxSpec(
      '07/09',
      '',
      formBox: 'modelo303/07/09',
      base: [_sales()],
      tax: [_sales()],
      baseKey: '07',
      taxKey: '09',
    ),
    VatBoxSpec(
      'Otros',
      '',
      formBox: 'modelo303/Otros',
      base: [_sales()],
      tax: [_sales()],
    ),
    VatBoxSpec(
      '27',
      'Total cuota devengada',
      tax: [_sales()],
      taxKey: '27',
      always: true,
    ),
    VatBoxSpec(
      '28/29',
      'Por cuotas soportadas en operaciones interiores corrientes',
      base: [_input(categories: _taxable)],
      tax: [_input(categories: _taxable)],
      baseKey: '28',
      taxKey: '29',
    ),
    VatBoxSpec(
      '30/31',
      'Por cuotas soportadas en operaciones interiores con bienes de inversión',
      base: [_input(categories: _asset)],
      tax: [_input(categories: _asset)],
      baseKey: '30',
      taxKey: '31',
    ),
    const VatBoxSpec(
      '45',
      'Total a deducir',
      tax: [VatTerm.box('28/29', tax: true), VatTerm.box('30/31', tax: true)],
      taxKey: '45',
      always: true,
    ),
    const VatBoxSpec(
      '46',
      'Resultado régimen general',
      tax: [
        VatTerm.box('27', tax: true),
        VatTerm.box('45', tax: true, factor: -1),
      ],
      taxKey: '46',
      always: true,
    ),
    VatBoxSpec(
      '59',
      'Entregas intracomunitarias de bienes y servicios',
      base: [
        _sales(categories: {'AE'}),
      ],
      baseKey: '59',
    ),
    VatBoxSpec(
      '60',
      'Exportaciones y operaciones asimiladas',
      base: [
        _sales(categories: {'Z'}),
      ],
      baseKey: '60',
    ),
    VatBoxSpec(
      '120',
      'Operaciones no sujetas por reglas de localización',
      base: [
        _sales(categories: {'G', 'O'}),
      ],
      baseKey: '120',
    ),
  ],
);

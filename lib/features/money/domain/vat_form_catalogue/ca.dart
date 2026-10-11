// SPDX-License-Identifier: AGPL-3.0-or-later
part of '../vat_form_catalogue.dart';

final _gst34 = VatFormSpec(
  country: 'CA',
  name: 'GST/HST return (GST34)',
  validFrom: DateTime(2024),
  boxes: [
    VatBoxSpec(
      '101',
      'Sales and other revenue',
      base: [_sales(categories: null)],
      baseKey: '101',
      baseRounding: _w,
      always: true,
    ),
    VatBoxSpec(
      '103',
      'GST/HST collected or collectible',
      tax: [_sales(correction: false)],
      taxKey: '103',
      always: true,
    ),
    VatBoxSpec(
      '104',
      'Adjustments to be added to the net tax',
      tax: [_sales(correction: true, vatSign: 1)],
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
      tax: [_input()],
      taxKey: '106',
    ),
    VatBoxSpec(
      '107',
      'Adjustments to be deducted when determining the net tax',
      tax: [_sales(correction: true, vatSign: -1, factor: -1)],
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

// SPDX-License-Identifier: AGPL-3.0-or-later
// test-inventory: pure rules — the invariant is that the split of a combined rate is read from rate_component rows
//
// #2539 -- the taxes inside a combined Canadian rate are `rate_component` rows
// of the tax reference store (server twin `vat_percent_components`, pgTAP 180
// and 201), not a table in Dart. The bundled copy answers what the code
// answered before; a row added or withdrawn changes the answer.
import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/vat_components.dart';
import 'package:deskilo/features/money/presentation/widgets/tax_reference_component_fields.dart';
import 'package:flutter_test/flutter_test.dart';

String _split(String country, double percent, {TaxReferenceSet? reference}) =>
    vatComponentsOf(country, percent, 100000, (100000 * percent / 100).round(),
            reference: reference)
        .map((c) => '${c.scheme}:${c.authority}:${c.percent}')
        .join(' ');

TaxReferenceRow _row(String key, double percent, List<RateComponent> parts,
        {String validFrom = '1900-01-01', String? validTo}) =>
    TaxReferenceRow(
      country: 'CA',
      key: key,
      validFrom: validFrom,
      validTo: validTo,
      value: RateComponentValue(percent: percent, components: parts),
      source: 'test',
      confirmed: true,
    );

void main() {
  test('the bundled rows split every Canadian rate as the catalogue did', () {
    expect(_split('CA', 5), 'GST:CA:5.0');
    expect(_split('CA', 13), 'HST:CA:13.0');
    expect(_split('CA', 14), 'HST:CA:14.0');
    expect(_split('CA', 15), 'HST:CA:15.0');
    expect(_split('CA', 14.975), 'GST:CA:5.0 QST:CA-QC:9.975');
    expect(_split('ca', 12), 'GST:CA:5.0 PST:CA-PST:7.0');
    expect(_split('CA', 11), 'GST:CA:5.0 PST:CA-PST:6.0');
  });

  test('a rate the data does not know, and a country with no rows, are not split', () {
    expect(_split('CA', 7.5), '');
    expect(_split('FR', 14.975), '');
    expect(_split('', 5), '');
  });

  test('the amounts still add up to the cent: GST 50.00 + QST 99.75 on 1 000.00', () {
    final parts = vatComponentsOf('CA', 14.975, 100000, 14975);
    expect(parts.map((c) => c.taxCents), [5000, 9975]);
    expect(parts.every((c) => c.baseCents == 100000), isTrue);
  });

  test('a row added to the data is honoured (positive control)', () {
    final base = ActiveTaxReference.current;
    expect(_split('CA', 7.5, reference: base), '');
    final extended = TaxReferenceSet([
      ...base.rows,
      _row('7.5', 7.5, const [
        RateComponent(scheme: 'GST', authority: 'CA', percent: 5),
        RateComponent(scheme: 'PST', authority: 'CA-PST', percent: 2.5),
      ]),
    ]);
    expect(_split('CA', 7.5, reference: extended), 'GST:CA:5.0 PST:CA-PST:2.5');
  });

  test('a version that has ended is not read; the one in force on the day is', () {
    final set = TaxReferenceSet([
      _row('9', 9, const [RateComponent(scheme: 'HST', authority: 'CA', percent: 9)],
          validTo: '2026-01-01'),
      _row('9', 9, const [
        RateComponent(scheme: 'GST', authority: 'CA', percent: 5),
        RateComponent(scheme: 'PST', authority: 'CA-PST', percent: 4),
      ], validFrom: '2026-01-01'),
    ]);
    expect(
      vatComponentsOf('CA', 9, 1000, 90, reference: set, asOf: '2025-06-01').single.scheme,
      'HST',
    );
    expect(
      vatComponentsOf('CA', 9, 1000, 90, reference: set, asOf: '2026-06-01').map((c) => c.scheme),
      ['GST', 'PST'],
    );
  });

  test('the row reads back through the wire shape', () {
    final row = TaxReferenceRow.fromJson({
      'domain': 'rate_component',
      'country': 'CA',
      'key': '14.975',
      'valid_from': '1900-01-01',
      'value': {
        'percent': 14.975,
        'components': [
          {'scheme': 'GST', 'authority': 'CA', 'percent': 5},
          {'scheme': 'QST', 'authority': 'CA-QC', 'percent': 9.975},
        ],
      },
      'source': 'ETA s. 165',
      'confirmed': true,
    });
    final value = row.value as RateComponentValue;
    expect(value.percent, 14.975);
    expect(value.components.map((c) => c.authority), ['CA', 'CA-QC']);
    expect(TaxReferenceRow.fromJson(row.toJson()).value.toJson(), value.toJson());
  });

  test('the editor refuses components that do not add up to the rate', () {
    final parts = parseRateComponents('GST, CA, 5\nQST, CA-QC, 9.975');
    expect(rateComponentsAddUp(parts, 14.975), isTrue);
    expect(rateComponentsAddUp(parts, 14), isFalse);
    expect(rateComponentsAddUp(null, 5), isFalse);
    expect(parseRateComponents(''), isNull);
    expect(parseRateComponents('GST, CA'), isNull);
    expect(parseRateComponents('GST, CA, x'), isNull);
    expect(parseRateComponents('GST, CA, 0'), isNull);
    expect(rateComponentsText(RateComponentValue(percent: 14.975, components: parts!)),
        'GST, CA, 5\nQST, CA-QC, 9.975');
  });
}

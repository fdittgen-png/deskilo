// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2362 -- the two sales-tax domains of the tax reference store and the
// editor's reading of a postal code's jurisdictions: a row decodes to its
// typed value and writes back the same JSON the server validates, a gate
// names its tax system, and a line of jurisdictions that is not
// `level, name, percent` is refused rather than guessed.
import 'package:deskilo/core/data/json_reader.dart';
import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/features/money/presentation/widgets/tax_reference_sales_fields.dart';
import 'package:flutter_test/flutter_test.dart';

TaxValue _read(TaxDomain domain, Map<String, Object?> json) =>
    TaxValue.parse(domain, JsonReader(json, context: 'test'));

void main() {
  test('a sales tax row decodes and writes back the same JSON', () {
    const json = {
      'state': 'NY',
      'components': [
        {'level': 'state', 'label': 'New York State', 'percent': 4.0},
        {'level': 'city', 'label': 'New York City', 'percent': 4.5},
      ],
    };
    final value = _read(TaxDomain.salesTax, json) as SalesTaxValue;
    expect(value.state, 'NY');
    expect(value.percent, 8.5);
    expect(value.toJson(), json);
  });

  test('a taxability row and a gate with a sales tax system round-trip', () {
    expect(
      (_read(TaxDomain.taxability, {
        'status': 'exempt',
      }) as TaxabilityValue).status,
      'exempt',
    );
    final gate = _read(TaxDomain.issuingGate, {
      'supported': true,
      'requires_tax_number': false,
      'national_channel_required': false,
      'currency': 'USD',
      'tax_system': 'sales_tax',
    }) as IssuingGateValue;
    expect(gate.salesTaxMode, isTrue);
    expect(gate.toJson()['tax_system'], 'sales_tax');
    // A gate without the key is a VAT gate and writes no key: every row that
    // existed before reads and writes as it did.
    final vat = _read(TaxDomain.issuingGate, {
      'supported': true,
      'requires_tax_number': false,
      'national_channel_required': false,
    }) as IssuingGateValue;
    expect(vat.salesTaxMode, isFalse);
    expect(vat.toJson().containsKey('tax_system'), isFalse);
  });

  test('the editor reads one jurisdiction per line and refuses the rest', () {
    final parsed = parseSalesTaxComponents(
      'state, New York State, 4\ncity, New York City, 4.5\n\ndistrict, MCTD, 0.375',
    );
    expect(parsed!.map((c) => c.level), ['state', 'city', 'district']);
    expect(parsed.last.percent, 0.375);
    // a name with a comma keeps it
    expect(
      parseSalesTaxComponents('city, Washington, DC, 6')!.single.label,
      'Washington, DC',
    );
    expect(parseSalesTaxComponents(''), isNull);
    expect(parseSalesTaxComponents('state, New York State'), isNull);
    expect(parseSalesTaxComponents('state, New York State, abc'), isNull);
    expect(parseSalesTaxComponents('state, New York State, 21'), isNull);
    expect(
      salesTaxComponentsText(
        _read(TaxDomain.salesTax, {
          'state': 'NY',
          'components': [
            {'level': 'state', 'label': 'New York State', 'percent': 4.0},
          ],
        }) as SalesTaxValue,
      ),
      'state, New York State, 4',
    );
  });
}

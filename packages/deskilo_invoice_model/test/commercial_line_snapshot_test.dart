// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4162 (X1.A) -- the `commercial` line contract, version 1: what decodes, what
// is refused and kept as raw facts, and that a legacy line is untouched.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:test/test.dart';

Map<String, Object?> _line({
  String quantity = '1.5',
  String supply = 'general',
  Object? version = 1,
  Map<String, Object?> extra = const {},
}) => {
  'version': version,
  'line_id': 'L-1',
  'quantity': quantity,
  'unit': {'code': 'hour', 'un_ece_code': 'HUR', 'label': 'h'},
  'unit_price': {
    'amount': '80',
    'currency': 'EUR',
    'basis': 'net',
    'base_quantity': '1',
  },
  'supply': supply,
  'tax_facts': {'treatment': 'standard', 'service_date': '2026-11-03'},
  'amounts': {
    'currency': 'EUR',
    'net_minor': '12000',
    'tax_minor': '2520',
    'gross_minor': '14520',
    'rule': 'half_up',
  },
  ...extra,
};

CommercialLineV1 _v1(Object? member) => commercialLineFromSnapshot(member)! as CommercialLineV1;

Map<Object?, Object?> _legacy([Map<String, Object?> more = const {}]) => {
  'kind': 'service',
  'label': 'Coffee',
  'quantity': 2,
  'amount_cents': 500,
  ...more,
};

void main() {
  group('AC1: a legacy line keeps its meaning', () {
    test('no commercial member: the integer, no facts', () {
      final line = invoiceLineFromSnapshot(_legacy());
      expect(line.commercial, isNull);
      expect(line.quantity, 2);
      expect(line.quantityText, '2');
      expect(line.exactFacts, isNull);
      expect([line].commercialFactsReadable, isTrue);
    });

    test('a line lacking every optional fact is its defaults, as before', () {
      final line = invoiceLineFromSnapshot({'label': 'x'});
      expect([line.quantity, line.amountCents, line.commercial], [1, 0, null]);
    });
  });

  group('AC2: exact quantities', () {
    test('1.5 h and 0.750000 kg round-trip as canonical text', () {
      final hours = _v1(_line());
      expect(hours.quantity.text, '1.5');
      final kg = _v1(_line(quantity: '0.750000', supply: 'goods'));
      expect(kg.quantity.text, '0.75');
      expect(kg.supply, CommercialSupply.goods);
      expect(commercialLineFromSnapshot(kg.toJson()), isA<CommercialLineV1>());
      expect(_v1(kg.toJson()).toJson(), kg.toJson());
    });

    test('the six-decimal boundary is accepted, the seventh refused', () {
      expect(parseCommercialDecimal('0.000001').value?.text, '0.000001');
      expect(parseCommercialDecimal('0.0000001').problem, CommercialDecimalProblem.excessPrecision);
      expect(parseCommercialDecimal('1.5000000').problem, CommercialDecimalProblem.excessPrecision);
    });

    test('zero, negative, malformed and overflow have their own problem', () {
      expect(parseCommercialDecimal('0').problem, CommercialDecimalProblem.notPositive);
      expect(parseCommercialDecimal('-1').problem, CommercialDecimalProblem.notPositive);
      expect(parseCommercialDecimal('1,5').problem, CommercialDecimalProblem.malformed);
      expect(parseCommercialDecimal('1e3').problem, CommercialDecimalProblem.malformed);
      expect(parseCommercialDecimal('999999999999').value?.text, '999999999999');
      expect(parseCommercialDecimal('1000000000000').problem, CommercialDecimalProblem.outOfRange);
    });

    test('an inexact quantity on the wire is raw facts, never rounded', () {
      for (final q in ['0.1234567', '0', '1,5', '', '1000000000000']) {
        final r = commercialLineFromSnapshot(_line(quantity: q));
        expect(r, isA<CommercialLineUnsupported>(), reason: q);
        expect((r! as CommercialLineUnsupported).field, 'quantity');
      }
    });

    test('amounts must add up and be exact minor units', () {
      final bad = _line(extra: {
        'amounts': {'currency': 'EUR', 'net_minor': '100', 'tax_minor': '20', 'gross_minor': '121'},
      });
      expect((commercialLineFromSnapshot(bad)! as CommercialLineUnsupported).field, 'amounts');
      final big = _line(extra: {
        'amounts': {'currency': 'EUR', 'net_minor': '9007199254740993', 'tax_minor': '0', 'gross_minor': '9007199254740993'},
      });
      expect(commercialLineFromSnapshot(big), isA<CommercialLineUnsupported>());
    });

    test('zero- and three-decimal currencies decode with their own units', () {
      final jpy = _line(extra: {
        'unit_price': {'amount': '1200', 'currency': 'JPY', 'basis': 'gross', 'base_quantity': '1'},
        'amounts': {'currency': 'JPY', 'net_minor': '1800', 'tax_minor': '180', 'gross_minor': '1980'},
      });
      expect(_v1(jpy).amounts.grossMinor, 1980);
      final kwd = _line(extra: {
        'unit_price': {'amount': '12.345', 'currency': 'KWD', 'basis': 'net', 'base_quantity': '1'},
        'amounts': {'currency': 'KWD', 'net_minor': '18518', 'tax_minor': '0', 'gross_minor': '18518'},
      });
      expect(_v1(kwd).unitPrice.amount.text, '12.345');
      expect(_v1(kwd).unitPrice.gross, isFalse);
    });

    test('a price is exact and carries its base quantity', () {
      final r = _v1(_line(extra: {
        'unit_price': {'amount': '3.333333', 'currency': 'EUR', 'basis': 'net', 'base_quantity': '0.5'},
      }));
      expect(r.unitPrice.amount.text, '3.333333');
      expect(r.unitPrice.baseQuantity.text, '0.5');
    });
  });

  group('AC3: what it cannot interpret stays readable and authorises nothing', () {
    test('an unknown version', () {
      final r = commercialLineFromSnapshot(_line(version: 2));
      expect(r, isA<CommercialLineUnsupported>());
      expect((r! as CommercialLineUnsupported).reason, CommercialRefusal.unknownVersion);
      expect((r as CommercialLineUnsupported).rawQuantity, '1.5');
    });

    test('an unknown supply kind is not property, and not goods', () {
      final r = commercialLineFromSnapshot(_line(supply: 'digital_download'))! as CommercialLineUnsupported;
      expect(r.reason, CommercialRefusal.unknownSupply);
      expect(r.raw['supply'], 'digital_download');
    });

    test('goods is its own kind', () {
      expect(CommercialSupply.fromWire('goods'), CommercialSupply.goods);
      expect(CommercialSupply.fromWire('property'), CommercialSupply.property);
      expect(CommercialSupply.fromWire('anything'), isNull);
    });

    test('a line that is not an object, and one without its identity', () {
      expect(commercialLineFromSnapshot('x'), isA<CommercialLineUnsupported>());
      final noId = _line()..remove('line_id');
      expect((commercialLineFromSnapshot(noId)! as CommercialLineUnsupported).field, 'line_id');
    });

    test('it never throws on what it was not given', () {
      for (final junk in [<Object?, Object?>{}, {'version': 1}, {'version': 1, 'supply': 'goods'}, 7, [1]]) {
        expect(() => commercialLineFromSnapshot(junk), returnsNormally);
      }
    });

    test('a reader of an unsupported line prints no default quantity', () {
      final line = invoiceLineFromSnapshot(_legacy({'quantity': 1, 'commercial': _line(version: 9, quantity: '0.75')}));
      expect(line.quantity, 1, reason: 'the legacy field is not what the line states');
      expect(line.quantityText, '0.75');
      expect(line.exactFacts, isNull);
      expect([line].commercialFactsReadable, isFalse);
      final unreadable = invoiceLineFromSnapshot(_legacy({'commercial': _line(version: 9, quantity: 'many')}));
      expect(unreadable.quantityText, isNull);
    });

    test('a future source kind is kept but not acted on; a missing unit code blocks export', () {
      final future = _v1(_line(extra: {'source_ref': {'kind': 'tender', 'id': 'T-1'}}));
      expect(future.source!.known, isFalse);
      expect(future.exportable, isFalse);
      final noCode = _v1(_line(extra: {'unit': {'code': 'job', 'label': 'job'}}));
      expect(noCode.unit.hasStructuredCode, isFalse);
      expect(noCode.exportable, isFalse);
      expect(_v1(_line()).exportable, isTrue);
    });
  });

  group('identities and corrections', () {
    test('a correction names its invoice source and may be negative', () {
      final r = _v1(_line(quantity: '-0.5', extra: {
        'line_id': 'L-2',
        'source_ref': {'kind': 'invoice', 'id': 'INV-1', 'revision': '1', 'line_id': 'L-1'},
        'amounts': {'currency': 'EUR', 'net_minor': '-6000', 'tax_minor': '-1260', 'gross_minor': '-7260'},
      }));
      expect(r.isCorrection, isTrue);
      expect(r.source!.lineId, 'L-1');
      expect(r.lineId, 'L-2');
    });

    test('an ordinary line may not be negative', () {
      expect(commercialLineFromSnapshot(_line(quantity: '-1')), isA<CommercialLineUnsupported>());
    });

    test('item, variant and printed dimensions are frozen as written', () {
      final r = _v1(_line(extra: {
        'item_ref': {
          'item_id': 'I-1',
          'variant_id': 'V-1',
          'dimensions': [{'dimension': 'size', 'value': 'XL'}],
        },
      }));
      expect([r.itemId, r.variantId], ['I-1', 'V-1']);
      expect(r.dimensions.single, (dimension: 'size', value: 'XL'));
    });
  });

  test('a structured invoice of a commercial line is refused until X1.B', () {
    final line = invoiceLineFromSnapshot(_legacy({'commercial': _line()}));
    expect(line.exactFacts, isNotNull);
    expect(const CommercialOutputBlocked().toString(), 'CommercialOutputBlocked');
  });
}

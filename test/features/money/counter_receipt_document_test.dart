// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4184 (CS1) -- the versioned reader of a frozen counter receipt: version 1 as the finalize of 0894 freezes it is
// read, any other version is refused rather than guessed, keys a later writer adds are ignored, a correction cites its
// original, and the document's words and totals agree in currencies of 0, 2 and 3 decimals. A document whose amounts
// disagree is said to disagree.
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/features/money/domain/counter_receipt_document.dart';
import 'package:deskilo/features/money/presentation/counter_receipt_view.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

final _en = AppLocalizationsEn();

/// A line as `counter_line_compute` freezes it: the integer `amount_cents`, the decimal-string amounts.
Map<String, Object?> _line(String label, String quantity, int net, int tax, {String unit = 'pc', Object vat = 20}) => {
  'kind': 'goods',
  'label': label,
  'quantity': 1,
  'amount_cents': net + tax,
  'vat_percent': vat,
  'vat_category': 'S',
  'supply': 'goods',
  'commercial': {
    'version': 1,
    'line_id': 'l-$label',
    'quantity': quantity,
    'unit': {'code': 'H87', 'un_ece_code': 'H87', 'label': unit},
    'unit_price': {'amount': '1', 'currency': 'EUR', 'basis': 'gross', 'base_quantity': '1'},
    'supply': 'goods',
    'tax_facts': {'tax_point': '2026-11-23', 'category': 'S', 'vat_percent': vat},
    'amounts': {'currency': 'EUR', 'net_minor': '$net', 'tax_minor': '$tax', 'gross_minor': '${net + tax}', 'rule': 'half_up_per_line'},
  },
};

/// A version-1 document as `counter_receipt_finalize_v1` writes it.
Map<String, Object?> _frozen(String currency, List<Map<String, Object?>> lines, {Object? version = 1, Map<String, Object?>? corrects}) {
  int sum(String k) => lines.fold(0, (a, l) => a + int.parse('${((l['commercial']! as Map)['amounts']! as Map)[k]}'));
  return {
    'version': version,
    'number': 'R-00007',
    'currency': currency,
    'price_basis': 'gross',
    'issued_at': '2026-11-23T10:15:00Z',
    'tax_point': '2026-11-23',
    'lines': lines,
    'totals': {'net_minor': '${sum('net_minor')}', 'tax_minor': '${sum('tax_minor')}', 'gross_minor': '${sum('gross_minor')}', 'currency': currency},
    'tax_breakdown': [
      {'percent': 20, 'category': 'S', 'gross_minor': '${sum('gross_minor')}', 'net_minor': '${sum('net_minor')}', 'tax_minor': '${sum('tax_minor')}'},
    ],
    'source': {'kind': 'counter', 'ref': ''},
    'financial_subject_id': null,
    'operation': {
      'country': 'FR',
      'operation': 'issue_receipt',
      'regime': 'none',
      'specification': 'Code général des impôts, annexe II, art. 242 nonies A (mentions des factures)',
      'specification_version': '2026-11',
      'effective_from': '2013-01-01',
      'adapter': 'counter_receipt_v1',
      'confirmed': false,
    },
    'corrects': corrects,
  };
}

AppFormat _format(String currency) => AppFormat(locale: 'en_US', currencyCode: currency);

void main() {
  test('a version-1 receipt is read with its lines, tax breakdown, totals and the operation it was issued under', () {
    final doc = CounterReceiptDocument.decode(_frozen('EUR', [_line('Milk', '2', 350, 70), _line('Beans', '0.35', 700, 140, unit: 'kg')]));
    expect(doc.number, 'R-00007');
    expect(doc.currency, 'EUR');
    expect(doc.lines.map((l) => l.label), ['Milk', 'Beans']);
    expect(doc.lines[1].quantity, '0.35');
    expect(doc.lines[1].unit, 'kg');
    expect(doc.totals.grossMinor, 1260);
    expect(doc.totals.taxMinor, 210);
    expect(doc.taxBreakdown.single.taxMinor, 210);
    expect(doc.operation.country, 'FR');
    expect(doc.operation.specificationVersion, '2026-11');
    expect(doc.operation.confirmed, isFalse);
    expect(doc.isCorrection, isFalse);
    expect(doc.issuedAt, DateTime.utc(2026, 11, 23, 10, 15));
    expect(doc.disagreements, isEmpty);
  });

  test('another version is refused, never guessed; a version 1 without its parts is refused too', () {
    for (final v in [2, 0, '1', null]) {
      expect(
        () => CounterReceiptDocument.decode(_frozen('EUR', [_line('Milk', '1', 175, 35)], version: v)),
        throwsA(isA<CounterReceiptUnreadable>()),
        reason: 'version $v',
      );
    }
    expect(() => CounterReceiptDocument.decode(null), throwsA(isA<CounterReceiptUnreadable>()));
    expect(() => CounterReceiptDocument.decode(_frozen('EUR', [])..remove('totals')), throwsA(isA<CounterReceiptUnreadable>()));
    expect(() => CounterReceiptDocument.decode(_frozen('eur', [])), throwsA(isA<CounterReceiptUnreadable>()));
    expect(() => CounterReceiptDocument.decode(_frozen('EUR', [])..['lines'] = 'none'), throwsA(isA<CounterReceiptUnreadable>()));
  });

  test('keys a later writer adds to version 1 are ignored: the old reader reads what it knows', () {
    final later = _frozen('EUR', [_line('Milk', '1', 175, 35)..['discount'] = {'minor': '10'}])
      ..['fiscal_signature'] = 'ABC'
      ..['deposit'] = {'minor': '25'};
    final doc = CounterReceiptDocument.decode(later);
    expect(doc.totals.grossMinor, 210);
    expect(doc.disagreements, isEmpty);
  });

  test('a correction cites its original and says so', () {
    final doc = CounterReceiptDocument.decode(
      _frozen('EUR', [_line('Milk', '1', 175, 35)], corrects: {'receipt_id': 'r-1', 'number': 'R-00001', 'reason': 'returned'}),
    );
    expect(doc.isCorrection, isTrue);
    expect(doc.corrects!.number, 'R-00001');
    expect(counterReceiptText(_en, _format('EUR'), doc), contains(_en.tillReceiptCorrects('R-00001')));
  });

  test('amounts that disagree are named, not repaired', () {
    final bad = _frozen('EUR', [_line('Milk', '1', 175, 35)]);
    (bad['totals']! as Map)['gross_minor'] = '999';
    final doc = CounterReceiptDocument.decode(bad);
    expect(doc.disagreements, containsAll(['totals', 'lines_gross', 'breakdown_gross']));
    expect(doc.totals.grossMinor, 999);
  });

  group('the document and its totals agree in every currency precision', () {
    for (final (currency, digits, net, tax, total) in const [
      ('JPY', 0, 1000, 100, '1,100'),
      ('EUR', 2, 1000, 200, '12.00'),
      ('KWD', 3, 1000, 50, '1.050'),
    ]) {
      test('$currency ($digits decimals)', () {
        final doc = CounterReceiptDocument.decode(_frozen(currency, [_line('Tea', '1', net, tax)]));
        expect(doc.disagreements, isEmpty);
        final text = counterReceiptText(_en, _format(currency), doc);
        final spelled = _format(currency).moneyIn(currency).formatMinor(net + tax);
        // one formatter for money: the receipt prints what the app's own formatter prints, so the digits (the currency's decimals)
        // are the contract here and the symbol, which is the ICU data's, is not pinned
        expect(spelled.replaceAll(RegExp(r'\s'), ''), contains(total));
        expect(text, contains(_en.tillReceiptTotal(spelled)));
        expect(text, contains(_en.tillReceiptTaxLine(_format(currency).ratePercent(20), _format(currency).moneyIn(currency).formatMinor(tax), _format(currency).moneyIn(currency).formatMinor(net))));
        expect(text, contains(_en.tillReceiptIssuedUnder(doc.operation.specification, '2026-11')));
      });
    }
  });

  test('a returned deposit is read as such and printed with its words (#4478)', () {
    final back = _line('Bottle', '2', -42, -8)..['returned'] = true..['kind'] = 'deposit_return';
    final doc = CounterReceiptDocument.decode(_frozen('EUR', [_line('Milk', '1', 175, 35), back]));
    expect([for (final l in doc.lines) l.returned], [false, true]);
    expect(counterReceiptText(_en, _format('EUR'), doc), contains(_en.tillReturnedLabel('Bottle')));
  });
}

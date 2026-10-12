// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2357 — the VAT return forms are data (`vat_form_catalogue.dart`): per
// country and year, each box selects the declaration lines it adds up by
// rate, category, direction and correction, totals add the rounded boxes,
// and each form rounds as the authority does. One fixture per form pins
// every box a coworking space fills.
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:deskilo/features/money/domain/vat_form_catalogue.dart';
import 'package:deskilo/features/money/domain/vat_forms.dart';
import 'package:flutter_test/flutter_test.dart';

VatDeclarationLine _sale(
  double percent,
  int net,
  int vat, {
  String category = 'S',
  String corrects = '',
}) => VatDeclarationLine(
  percent: percent,
  category: category,
  grossCents: net + vat,
  netCents: net,
  vatCents: vat,
  invoiceCount: 1,
  corrects: corrects,
);

VatDeclarationLine _input(
  int net,
  int vat, {
  String category = 'S',
  String corrects = '',
}) => VatDeclarationLine(
  percent: 20,
  category: category,
  grossCents: net + vat,
  netCents: net,
  vatCents: vat,
  invoiceCount: 1,
  corrects: corrects,
  direction: 'input',
);

/// The filled form of [country] as code → (base, tax), in cents.
Map<String, (int, int)> _form(String country, List<VatDeclarationLine> lines) =>
    {
      for (final b in vatFormBoxes(
        country,
        lines,
        periodEnd: DateTime(2026, 9, 30),
      ))
        b.code: (b.netCents, b.vatCents),
    };

void main() {
  group('rounding', () {
    test('whole units half away from zero, or cut', () {
      expect(VatRounding.wholeHalfUp.apply(250), 300);
      expect(VatRounding.wholeHalfUp.apply(249), 200);
      expect(VatRounding.wholeHalfUp.apply(-250), -300);
      expect(VatRounding.wholeDown.apply(199), 100);
      expect(VatRounding.wholeDown.apply(-199), -100);
      expect(VatRounding.cents.apply(199), 199);
    });
  });

  test('France — CA3 in whole euros, by rate and by category', () {
    final form = _form('FR', [
      _sale(20, 100010, 20002),
      _sale(0, 50049, 0, category: 'AE'),
      _sale(0, 30050, 0, category: 'G'),
      _sale(0, 8000, 0, category: 'E'),
      _sale(20, -4750, -950, corrects: 'aug'),
      _input(15750, 3150),
      _input(50245, 10049, category: 'asset'),
      _input(-600, -120, corrects: 'aug'),
    ]);
    expect(form['A1'], (100000, 0), reason: 'taxable sales, the euro rounded');
    expect(form['E1']!.$1, 30100, reason: 'exports: 300,50 rounds up');
    expect(form['E2']!.$1, 58000, reason: 'intra-EU services and exempt');
    expect(form['08'], (100000, 20000));
    expect(form['15']!.$2, 100, reason: 'input VAT paid back: 1,20');
    expect(form['16']!.$2, 20100);
    expect(form['19']!.$2, 10000, reason: 'a fixed asset');
    expect(form['20']!.$2, 3200, reason: 'other goods and services: 31,50');
    expect(form['21']!.$2, 1000, reason: 'the void in the declarant\'s favour');
    expect(form['23']!.$2, 14200);
    expect(form['28']!.$2, 5900, reason: '201 − 142');
    expect(form.containsKey('25'), isFalse, reason: 'no credit');
  });

  test('France — a credit when more is deductible than due', () {
    final form = _form('FR', [_sale(20, 1000, 200), _input(5000, 1000)]);
    expect(form['25']!.$2, 800);
    expect(form['28']!.$2, 0, reason: 'nothing due, still printed');
  });

  test('Germany — UStVA bases cut to the euro, Kz by category', () {
    final form = _form('DE', [
      _sale(19, 100099, 19019),
      _sale(7, 10050, 704),
      _sale(0, 20099, 0, category: 'AE'),
      _sale(0, 3000, 0, category: 'G'),
      _sale(0, 4000, 0, category: 'Z'),
      _sale(0, 5000, 0, category: 'E'),
      _input(69468, 13199),
    ]);
    expect(form['Kz 81'], (100000, 19019));
    expect(form['Kz 86'], (10000, 704));
    expect(form['Kz 21']!.$1, 20000);
    expect(form['Kz 45']!.$1, 3000);
    expect(form['Kz 43']!.$1, 4000);
    expect(form['Kz 48']!.$1, 5000);
    expect(form['Kz 66']!.$2, 13199);
    expect(form['Kz 83']!.$2, 19019 + 704 - 13199);
  });

  test('United Kingdom — boxes 1–5 in pence, 6–9 in whole pounds', () {
    final form = _form('GB', [
      _sale(20, 100099, 20020),
      _sale(0, 5050, 0, category: 'Z'),
      _input(15000, 3000),
    ]);
    expect(form['Box 1']!.$2, 20020);
    expect(form['Box 2']!.$2, 0);
    expect(form['Box 3']!.$2, 20020);
    expect(form['Box 4']!.$2, 3000);
    expect(form['Box 5']!.$2, 17020);
    expect(form['Box 6']!.$1, 105100);
    expect(form['Box 7']!.$1, 15000);
    expect(form['Box 8']!.$1, 0);
    expect(form['Box 9']!.$1, 0);
    expect(
      _form('UK', [_sale(20, 1000, 200), _input(5000, 1000)])['Box 5']!.$2,
      800,
      reason: 'box 5 states the difference without its sign',
    );
  });

  test('Switzerland — turnover, deductions, rates and input tax', () {
    final form = _form('CH', [
      _sale(8.1, 100000, 8100),
      _sale(0, 20000, 0, category: 'E'),
      _sale(0, 5000, 0, category: 'Z'),
      _input(6000, 500),
      _input(20000, 2000, category: 'asset'),
    ]);
    expect(form['200']!.$1, 125000);
    expect(form['220']!.$1, 5000);
    expect(form['230']!.$1, 20000);
    expect(form['289']!.$1, 25000);
    expect(form['299']!.$1, 100000);
    expect(form['303'], (100000, 8100));
    expect(form['399']!.$2, 8100);
    expect(form['400']!.$2, 500);
    expect(form['405']!.$2, 2000);
    expect(form['479']!.$2, 2500);
    expect(form['500']!.$2, 5600);
    expect(form.containsKey('510'), isFalse);
  });

  test('Canada — line 101 in whole dollars, corrections on 104 and 107', () {
    final form = _form('CA', [
      _sale(13, 100000, 13000),
      _sale(13, -10000, -1300, corrects: 'q2'),
      _input(20000, 2600),
    ]);
    expect(form['101']!.$1, 90000);
    expect(form['103']!.$2, 13000);
    expect(form.containsKey('104'), isFalse);
    expect(form['105']!.$2, 13000);
    expect(form['106']!.$2, 2600);
    expect(form['107']!.$2, 1300);
    expect(form['108']!.$2, 3900);
    expect(form['109']!.$2, 9100);
  });

  test('Spain — Modelo 303 by rate, current and capital input VAT', () {
    final form = _form('ES', [
      _sale(21, 100000, 21000),
      _sale(0, 50000, 0, category: 'AE'),
      _input(20000, 4200),
      _input(10000, 2100, category: 'asset'),
    ]);
    expect(form['07/09'], (100000, 21000));
    expect(form['27']!.$2, 21000);
    expect(form['28/29'], (20000, 4200));
    expect(form['30/31'], (10000, 2100));
    expect(form['45']!.$2, 6300);
    expect(form['46']!.$2, 14700);
    expect(form['59']!.$1, 50000);
  });

  test('Italy — the periodic settlement, quadro VP', () {
    final form = _form('IT', [_sale(22, 100000, 22000), _input(30000, 6600)]);
    expect(form['VP2']!.$1, 100000);
    expect(form['VP3']!.$1, 30000);
    expect(form['VP4']!.$2, 22000);
    expect(form['VP5']!.$2, 6600);
    expect(form['VP6 col. 1']!.$2, 15400);
    expect(form.containsKey('VP6 col. 2'), isFalse);
  });

  group('the catalogue', () {
    test('a form per country, the layout in force for the period', () {
      expect(
        vatFormSpecFor('fr', DateTime(2026, 9, 30))!.name,
        contains('CA3'),
      );
      expect(vatFormSpecFor('UK', DateTime(2026))!.country, 'GB');
      expect(
        vatFormSpecFor('DE', DateTime(2019))!.validFrom,
        DateTime(2024),
        reason: 'an older period reads the earliest layout',
      );
      expect(vatFormSpecFor('NO', DateTime(2026)), isNull);
    });

    test('a country without a form gets one box per rate', () {
      final form = _form('NO', [_sale(25, 1000, 250), _sale(15, 1000, 150)]);
      expect(form.keys, ['25 %', '15 %']);
    });

    test('every box of every form has a code and a label, unique per form', () {
      for (final spec in vatFormCatalogue) {
        final codes = [for (final b in spec.boxes) b.code];
        expect(codes.toSet(), hasLength(codes.length), reason: spec.name);
        for (final b in spec.boxes) {
          expect(b.label, isNotEmpty, reason: '${spec.name} ${b.code}');
          expect(
            b.hasBase || b.hasTax,
            isTrue,
            reason: '${spec.name} ${b.code}',
          );
        }
      }
    });

    test('a total names only boxes that come before it', () {
      for (final spec in vatFormCatalogue) {
        final seen = <String>{};
        for (final b in spec.boxes) {
          for (final t in [...b.base, ...b.tax]) {
            if (t.box != null) {
              expect(seen, contains(t.box), reason: '${spec.name} ${b.code}');
            }
          }
          seen.add(b.code);
        }
      }
    });
  });
}

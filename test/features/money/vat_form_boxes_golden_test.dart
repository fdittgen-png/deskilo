// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2480 (C4 of #2476) -- the return form boxes select their lines by
// category and rate group, never by a percent. `golden/vat_form_boxes_golden.json`
// was captured from the literal rate sets BEFORE they were deleted: every box
// of every form, for a ledger that holds every rate, category, direction and
// correction, per period. The store's `form_box` rows reproduce it exactly.
//
// Run with GOLDEN_UPDATE=1 only to capture a deliberate change.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:flutter_test/flutter_test.dart';

const _goldenPath = 'test/features/money/golden/vat_form_boxes_golden.json';

VatDeclarationLine _line(
  double percent,
  int net,
  int vat, {
  String category = 'S',
  String direction = 'output',
  String corrects = '',
}) => VatDeclarationLine(
  percent: percent,
  category: category,
  grossCents: net + vat,
  netCents: net,
  vatCents: vat,
  invoiceCount: 1,
  direction: direction,
  corrects: corrects,
  correctsStart: corrects.isEmpty ? null : DateTime(2026),
  correctsEnd: corrects.isEmpty ? null : DateTime(2026, 3, 31),
);

const _rates = <double>[
  0,
  2.1,
  2.6,
  3.8,
  4,
  5,
  5.5,
  7,
  8.1,
  10,
  13,
  14.975,
  16,
  19,
  20,
  21,
  22,
  25,
];

/// The ledgers: each rate alone, a correction of each sign beside it, the
/// non-taxed categories, deductible VAT, and everything together.
Map<String, List<VatDeclarationLine>> _ledgers() {
  final every = <VatDeclarationLine>[];
  final out = <String, List<VatDeclarationLine>>{};
  for (final r in _rates) {
    final net = 100000 + (r * 1000).round();
    final vat = (net * r / 100).round();
    final sale = _line(r, net, vat);
    out['rate $r'] = [sale];
    out['rate $r + corrections'] = [
      sale,
      _line(r, 5000, (5000 * r / 100).round(), corrects: 'return-1'),
      _line(r, -3000, -(3000 * r / 100).round(), corrects: 'return-2'),
    ];
    every.add(sale);
  }
  for (final c in ['AE', 'E', 'Z', 'G', 'O']) {
    final line = _line(0, 40000, 0, category: c);
    out['category $c'] = [line];
    every.add(line);
  }
  final input = [
    _line(20, 80000, 16000, direction: 'input'),
    _line(20, 50000, 10000, direction: 'input', category: 'asset'),
    _line(20, 7000, -1400, direction: 'input', corrects: 'return-1'),
  ];
  out['inputs'] = input;
  out['everything'] = [...every, ...input];
  out['nothing'] = const [];
  return out;
}

Map<String, Object?> _capture() {
  final golden = <String, Object?>{};
  final periods = <String, DateTime?>{
    '2019-12-31': DateTime(2019, 12, 31),
    '2024-06-30': DateTime(2024, 6, 30),
    '2026-09-30': DateTime(2026, 9, 30),
    'open': null,
  };
  final ledgers = _ledgers();
  for (final country in ['DE', 'FR', 'ES', 'CH', 'GB', 'CA', 'IT', 'NO']) {
    for (final p in periods.entries) {
      for (final l in ledgers.entries) {
        golden['$country|${p.key}|${l.key}'] = [
          for (final b in vatFormBoxes(country, l.value, periodEnd: p.value))
            [
              b.code,
              b.label,
              b.netCents,
              b.vatCents,
              b.hasBase,
              b.hasTax,
              b.baseKey,
              b.taxKey,
            ],
        ];
      }
    }
  }
  return golden;
}

void main() {
  test('every box of every form is what the literal rate sets produced', () {
    final got = _capture();
    if (Platform.environment['GOLDEN_UPDATE'] == '1') {
      File(_goldenPath).writeAsStringSync(
        '{\n'
        '${got.entries.map((e) => '${jsonEncode(e.key)}:${jsonEncode(e.value)}').join(',\n')}'
        '\n}\n',
      );
      return;
    }
    final expected = jsonDecode(
      File(_goldenPath).readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(got.keys.toSet(), expected.keys.toSet());
    for (final k in expected.keys) {
      expect(jsonDecode(jsonEncode(got[k])), expected[k], reason: k);
    }
  });

  group('the data decides, the code does not', () {
    TaxReferenceSet with_(
      List<TaxReferenceRow> add, {
      bool Function(TaxReferenceRow)? close,
      String? closeOn,
    }) {
      final rows = [
        for (final r in ActiveTaxReference.current.rows)
          if (close != null && close(r)) r.closedOn(closeOn!) else r,
        ...add,
      ];
      return TaxReferenceSet(rows);
    }

    TaxReferenceRow rate(
      String country,
      String key,
      String from,
      double pct,
      String group,
    ) => TaxReferenceRow(
      country: country,
      key: key,
      validFrom: from,
      value: RateValue(
        label: '$pct',
        percent: pct,
        group: group,
        category: 'S',
      ),
      source: 'test',
      confirmed: true,
    );

    Map<String, (int, int)> boxes(
      String c,
      List<VatDeclarationLine> l,
      DateTime end,
      TaxReferenceSet ref,
    ) => {
      for (final b in vatFormBoxes(c, l, periodEnd: end, reference: ref))
        b.code: (b.netCents, b.vatCents),
    };

    test('Germany raises its standard rate: both rates land in Kz 81, no code edit', () {
      final ref = with_(
        [rate('DE', 'standard', '2027-01-01', 20, 'standard')],
        close: (r) =>
            r.domain == TaxDomain.rate &&
            r.country == 'DE' &&
            r.key == 'standard',
        closeOn: '2027-01-01',
      );
      final old = _line(19, 100000, 19000);
      final fresh = _line(20, 100000, 20000);
      final straddling = boxes('DE', [old, fresh], DateTime(2027, 3, 31), ref);
      expect(straddling['Kz 81'], (200000, 39000));
      expect(straddling.containsKey('Kz 35/36'), isFalse);
      expect(boxes('DE', [old], DateTime(2026, 12, 31), ref)['Kz 81'], (
        100000,
        19000,
      ));
      expect(boxes('DE', [fresh], DateTime(2027, 12, 31), ref)['Kz 81'], (
        100000,
        20000,
      ));
    });

    test('a box edited in the store changes the next return and not a filed period', () {
      const edited = TaxReferenceRow(
        country: 'DE',
        key: 'ustva/Kz 86',
        validFrom: '2026-01-01',
        value: FormBoxValue(label: 'Neu', groups: ['reduced', 'standard']),
        source: 'test',
        confirmed: true,
      );
      final ref = with_(
        [edited],
        close: (r) =>
            r.domain == TaxDomain.formBox &&
            r.country == 'DE' &&
            r.key == 'ustva/Kz 86',
        closeOn: '2026-01-01',
      );
      final lines = [_line(19, 100000, 19000), _line(7, 50000, 3500)];
      final filed = vatFormBoxes(
        'DE',
        lines,
        periodEnd: DateTime(2025, 6, 30),
        reference: ref,
      );
      final next = vatFormBoxes(
        'DE',
        lines,
        periodEnd: DateTime(2026, 6, 30),
        reference: ref,
      );
      String label(List<VatFormBox> l, String c) =>
          l.firstWhere((b) => b.code == c).label;
      expect(
        label(filed, 'Kz 86'),
        'Steuerpflichtige Umsätze zum Steuersatz von 7 %',
      );
      expect(filed.firstWhere((b) => b.code == 'Kz 86').netCents, 50000);
      expect(label(next, 'Kz 86'), 'Neu');
      expect(next.firstWhere((b) => b.code == 'Kz 86').netCents, 150000);
      // Nothing was regenerated: the same ledger read again, same answers.
      expect(
        [
          for (final b in vatFormBoxes(
            'DE',
            lines,
            periodEnd: DateTime(2025, 6, 30),
            reference: ref,
          ))
            b.netCents,
        ],
        [for (final b in filed) b.netCents],
      );
    });

    test(
      'a rated box with no row fails loudly instead of printing a blank box',
      () {
        const ref = TaxReferenceSet([]);
        expect(
          () => vatFormBoxes('DE', const [], reference: ref),
          throwsA(isA<TaxReferenceUnavailable>()),
        );
      },
    );
  });
}

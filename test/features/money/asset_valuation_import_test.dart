// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2576 (C2) -- the valuation CSV: a blank figure is unknown and stays
// unknown, amounts are exact signed integers, one batch has one basis, one
// period and one currency, and every problem is named with its line.
import 'package:deskilo/features/money/domain/asset_valuation.dart';
import 'package:flutter_test/flutter_test.dart';

const _head =
    'AssetNumber,Basis,PeriodFrom,PeriodTo,Currency,OpeningMinor,AdditionsMinor,'
    'DisposalsMinor,DepreciationMinor,ImpairmentMinor,ClosingMinor,ExternalReference';

String _file(List<String> rows) => '$_head\n${rows.join('\n')}\n';

void main() {
  test('the sample reads: one balanced row, one wholly unknown', () {
    final csv = readValuationCsv(valuationSampleCsv());
    expect(csv.issues, isEmpty);
    expect(csv.usable, isTrue);
    expect(csv.basis, ValuationBasis.book);
    expect(csv.currency, 'EUR');
    expect(csv.rows.map((r) => r.bridge), [
      ValuationBridge.ok,
      ValuationBridge.unknown,
    ]);
    expect(csv.rows.last.closingMinor, isNull, reason: 'blank is not zero');
    expect(csv.rows.first.externalReference, 'FA-0001');
    expect(csv.sha256Hex, hasLength(64));
  });

  test('the same bytes have the same hash, one changed byte another', () {
    final a = readValuationCsv(valuationSampleCsv()).sha256Hex;
    expect(readValuationCsv(valuationSampleCsv()).sha256Hex, a);
    expect(readValuationCsv('${valuationSampleCsv()} ').sha256Hex, isNot(a));
  });

  test('a row that does not balance is flagged, not refused', () {
    final csv = readValuationCsv(
      _file(['1,tax,2026-01-01,2026-12-31,EUR,1000,0,0,100,0,800,']),
    );
    expect(csv.issues, isEmpty);
    expect(csv.mismatches, 1);
    expect(csv.basis, ValuationBasis.tax);
  });

  test(
    'signed integers are exact; decimals, exponents and formulas are not',
    () {
      for (final bad in [
        '12.5',
        '1e3',
        '=1+1',
        '12,5',
        '0x10',
        '9007199254740992',
      ]) {
        final csv = readValuationCsv(
          _file(['1,book,2026-01-01,2026-12-31,EUR,"$bad",0,0,0,0,0,']),
        );
        expect(
          csv.issues.map((i) => i.kind),
          contains(ValuationIssueKind.minor),
          reason: bad,
        );
        expect(csv.usable, isFalse);
      }
      final signed = readValuationCsv(
        _file(['1,book,2026-01-01,2026-12-31,EUR,+10,0,-5,0,0,15,']),
      );
      expect(signed.issues, isEmpty);
      expect(signed.rows.single.disposalsMinor, -5);
    },
  );

  test('each problem names its line', () {
    final csv = readValuationCsv(
      _file([
        'x,book,2026-01-01,2026-12-31,EUR,,,,,,,',
        '2,gaap,2026-01-01,2026-12-31,EUR,,,,,,,',
        '3,book,2026-02-30,2026-12-31,EUR,,,,,,,',
        '4,book,2026-12-31,2026-01-01,EUR,,,,,,,',
        '5,book,2026-01-01,2026-12-31,EURO,,,,,,,',
        '6,book,2026-01-01',
      ]),
    );
    expect(
      {for (final i in csv.issues) i.line: i.kind},
      {
        2: ValuationIssueKind.assetNumber,
        3: ValuationIssueKind.basis,
        4: ValuationIssueKind.date,
        5: ValuationIssueKind.period,
        6: ValuationIssueKind.currency,
        7: ValuationIssueKind.columnCount,
      },
    );
  });

  test('one batch has one basis, period and currency, and an asset once', () {
    final csv = readValuationCsv(
      _file([
        '1,book,2026-01-01,2026-12-31,EUR,,,,,,,',
        '2,tax,2026-01-01,2026-12-31,EUR,,,,,,,',
        '3,book,2026-01-01,2026-06-30,EUR,,,,,,,',
        '4,book,2026-01-01,2026-12-31,USD,,,,,,,',
        '1,book,2026-01-01,2026-12-31,EUR,,,,,,,',
      ]),
    );
    expect(csv.issues.map((i) => '${i.line}:${i.kind.name}'), [
      '3:mixed',
      '4:mixed',
      '5:mixed',
      '6:duplicateAsset',
    ]);
  });

  test('a file that is not the format is refused as a whole', () {
    expect(readValuationCsv('').issues.single.kind, ValuationIssueKind.empty);
    expect(
      readValuationCsv('AssetNumber,Basis\n1,book').issues.single.kind,
      ValuationIssueKind.header,
    );
    expect(
      readValuationCsv(_head).issues.single.kind,
      ValuationIssueKind.empty,
    );
    expect(
      readValuationCsv('$_head\n"1,book').issues.single.kind,
      ValuationIssueKind.header,
    );
  });

  test('a byte-order mark, CRLF lines and quoted cells read like plain ones', () {
    final csv = readValuationCsv(
      '﻿$_head\r\n1,"book",2026-01-01,2026-12-31,eur,1,0,0,0,0,1,"FA, ""one"""\r\n',
    );
    expect(csv.issues, isEmpty);
    expect(csv.currency, 'EUR');
    expect(csv.rows.single.externalReference, 'FA, "one"');
  });

  test('more rows than a batch holds are refused', () {
    final rows = [
      for (var i = 1; i <= 101; i++) '$i,book,2026-01-01,2026-12-31,EUR,,,,,,,',
    ];
    final refused = readValuationCsv(_file(rows), maxRows: 100).issues.single;
    expect(refused.kind, ValuationIssueKind.tooManyRows);
    expect(refused.detail, '100', reason: 'the message names the limit in force');
    expect(readValuationCsv(_file(rows), maxRows: 101).usable, isTrue);
  });

  test('a stored batch and row read as the server writes them', () {
    final b = ValuationBatch.fromJson({
      'id': 'b1',
      'revision': 2,
      'basis': 'tax',
      'source_system': 'Cabinet Martin',
      'period_from': '2026-01-01',
      'period_to': '2026-12-31',
      'currency': 'EUR',
      'movements': 'ytd',
      'complete_scope': false,
      'status': 'confirmed',
      'rows': 2,
      'mismatches': 0,
    });
    expect(b.basis, ValuationBasis.tax);
    expect(b.status, ValuationStatus.confirmed);
    expect(b.movements, 'ytd');
    final r = ValuationRow.fromJson({
      'asset_id': 'a1',
      'asset_number': 3,
      'description': 'Machine',
      'closing_minor': null,
      'bridge': 'unknown',
    });
    expect(r.closingMinor, isNull);
    expect(r.bridge, ValuationBridge.unknown);
  });
}

// SPDX-License-Identifier: AGPL-3.0-or-later
// test-inventory: pure rules — the invariant is the Febelfin CODA record layout
//
// #2380 — a CODA statement is read from its 128-character records: the
// account and currency of the old balance, each movement with its value
// and entry days, signed amount (three decimals, the third zero), bank
// reference, Belgian structured communication or free text (an RF read
// from it when its check digits hold), counterparty from record 23; a
// globalised batch is its details, never its total as well. A record of
// the wrong length refuses the file and names its line.
import 'dart:io';

import 'package:deskilo/features/money/domain/bank/bank_file.dart';
import 'package:deskilo/features/money/domain/bank/bank_statement.dart';
import 'package:flutter_test/flutter_test.dart';

const _limits = BankFileLimits(maxBytes: 1 << 20, maxLines: 100);

final _records = File('test/features/money/fixtures/bank/coda_statement.cod')
    .readAsStringSync()
    .split('\r\n')
    .where((r) => r.isNotEmpty)
    .toList();

BankStatement _read(List<String> records) => parseBankFile(
  '${records.join('\r\n')}\r\n'.codeUnits,
  format: BankFileFormat.coda,
  limits: _limits,
);

/// [records] with the record at [index] changed at the 1-based [position].
List<String> _with(int index, int position, String value) => List.of(_records)
  ..[index] = _records[index].replaceRange(
    position - 1,
    position - 1 + value.length,
    value,
  );

Matcher _refused(BankFileProblem p, {int? line}) => throwsA(
  isA<BankFileException>()
      .having((e) => e.problem, 'problem', p)
      .having((e) => line == null || e.line == line, 'line', isTrue),
);

void main() {
  final s = _read(_records);

  test('the account, currency and balances', () {
    expect(s.format, BankFileFormat.coda);
    expect(s.account, 'BE68539007547034');
    expect(s.currency, 'EUR');
    expect(s.openingCents, 100000);
    expect(s.closingCents, 120550);
  });

  test('each movement with its fields; the batch is its details', () {
    expect(s.lines, hasLength(5));
    final [ogm, rf, out, one, two] = s.lines;
    expect(ogm.amountCents, 12000);
    expect(ogm.valueDate, DateTime.utc(2026, 1, 16));
    expect(ogm.bookingDate, DateTime.utc(2026, 1, 15));
    expect(ogm.transactionId, 'BANKREF0001');
    expect(ogm.reference, '090933755493');
    expect(ogm.counterpartyIban, 'BE71096123456769');
    expect(ogm.counterpartyName, 'Demo Member One');
    expect(rf.reference, 'RF18539007547034');
    expect(rf.remittance, 'Payment RF18 5390 0754 7034');
    expect(out.amountCents, -4500);
    expect(out.reference, '');
    expect(out.remittance, 'Office supplies January');
    expect([one.amountCents, two.amountCents], [3000, 2000]);
    expect(
      [one.transactionId, two.transactionId],
      ['BANKREF0004/1', 'BANKREF0004/2'],
    );
    expect(s.lines.map((l) => l.position), [1, 2, 3, 4, 5]);
  });

  test('a second read gives the same lines', () {
    expect(
      _read(_records).lines.map((l) => l.toJson()),
      s.lines.map((l) => l.toJson()),
    );
  });

  test('two equal movements with distinct bank references stay two', () {
    // Movement 2 takes movement 1's amount and days; its bank id differs.
    final twin = _read(
      List.of(_records)
        ..[5] = _records[5]
            .replaceRange(32, 47, _records[2].substring(32, 47))
            .replaceRange(47, 53, _records[2].substring(47, 53)),
    );
    final [a, b, ...] = twin.lines;
    expect((a.valueDate, a.amountCents), (b.valueDate, b.amountCents));
    expect(a.transactionId, isNot(b.transactionId));
  });

  group('refusals, one change each', () {
    test('a record longer than 128 characters names its line', () {
      expect(
        () => _read([
          ..._records.take(6),
          '${_records[6]}X',
          ..._records.skip(7),
        ]),
        _refused(BankFileProblem.malformed, line: 7),
      );
    });
    test('no header', () {
      expect(
        () => _read(_records.skip(1).toList()),
        _refused(BankFileProblem.malformed),
      );
    });
    test('a third decimal', () {
      expect(
        () => _read(_with(5, 47, '5')),
        _refused(BankFileProblem.badAmount),
      );
    });
    test('a value day that is not one', () {
      expect(
        () => _read(_with(5, 48, '300226')),
        _refused(BankFileProblem.badDate),
      );
    });
    test('a currency that is not one', () {
      expect(
        () => _read(_with(1, 40, 'E1R')),
        _refused(BankFileProblem.badCurrency),
      );
    });
    test('no account', () {
      expect(
        () => _read(_with(1, 6, ' ' * 16)),
        _refused(BankFileProblem.missingAccount),
      );
    });
    test('no movement', () {
      expect(
        () => _read([..._records.take(2), ..._records.skip(11)]),
        _refused(BankFileProblem.empty),
      );
    });
  });
}

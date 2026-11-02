// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Suppressed bank IDs map only to unique matching movements in the same account and currency.
import 'package:deskilo/features/money/domain/bank/bank_records.dart';
import 'package:deskilo/features/money/domain/bank/bank_statement.dart';
import 'package:deskilo/features/money/domain/bank/reconciliation_overlap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime.utc(2026);
  BankLine sourceLine(String id, int amount) => BankLine(
    position: 1,
    bookingDate: day,
    valueDate: day,
    amountCents: amount,
    currency: 'EUR',
    transactionId: id,
  );
  StoredBankLine stored(
    String id,
    int position,
    String transaction,
    int amount, {
    String currency = 'EUR',
  }) => StoredBankLine(
    id: id,
    position: position,
    bookingDate: day,
    valueDate: day,
    amountCents: amount,
    currency: currency,
    status: BankLineStatus.matched,
    transactionId: transaction,
  );
  final source = BankStatement(
    format: BankFileFormat.camt053,
    account: 'a',
    currency: 'EUR',
    lines: [sourceLine('one', 100), sourceLine('two', -20)],
  );
  final own = stored('current', 1, 'one', 100);
  final earlier = stored('earlier', 7, 'two', -20);
  final candidate = (account: 'a', currency: 'EUR', line: earlier);
  test('maps a suppressed source movement to its unique same-account canonical line', () {
    final result = mapBankSourceMovements(
      source: source,
      ownLines: [own],
      candidates: [candidate],
    );
    expect(result?.map((line) => line.id), ['current', 'earlier']);
  });
  test(
    'denies cross-account, mixed currency, conflicts and ambiguous identities',
    () {
      List<StoredBankLine>? resolve(List<BankCanonicalLine> rows) =>
          mapBankSourceMovements(
            source: source,
            ownLines: [own],
            candidates: rows,
          );
      expect(
        resolve([(account: 'other', currency: 'EUR', line: earlier)]),
        isNull,
      );
      expect(resolve([(account: 'a', currency: 'USD', line: earlier)]), isNull);
      expect(
        resolve([
          (account: 'a', currency: 'EUR', line: stored('wrong', 1, 'two', -21)),
        ]),
        isNull,
      );
      expect(
        resolve([
          candidate,
          (account: 'a', currency: 'EUR', line: stored('other', 3, 'two', -20)),
        ]),
        isNull,
      );
      expect(resolve([]), isNull);
    },
  );
  test('a gap without a bank transaction identity is not guessed', () {
    final noId = BankStatement(
      format: BankFileFormat.camt053,
      account: 'a',
      currency: 'EUR',
      lines: [sourceLine('one', 100), sourceLine('', -20)],
    );
    expect(
      mapBankSourceMovements(
        source: noId,
        ownLines: [own],
        candidates: [candidate],
      ),
      isNull,
    );
  });
}

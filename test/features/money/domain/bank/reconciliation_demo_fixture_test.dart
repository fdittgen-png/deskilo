// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Synthetic bank source balances and names its unmatched movement.
import 'dart:convert';

import 'package:deskilo/core/demo/data/bank_reconciliation_fixture.dart';
import 'package:deskilo/features/money/domain/bank/bank_file.dart';
import 'package:deskilo/features/money/domain/bank/bank_statement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Demo bank report source is balanced and names the unmatched line', () {
    final statement = parseBankFile(
      utf8.encode(demoReconciliationStatementXml),
      format: BankFileFormat.camt053,
      limits: const BankFileLimits(maxBytes: 100000, maxLines: 100),
    );
    expect(statement.openingCents, 10000);
    expect(statement.closingCents, 14000);
    expect(
      statement.lines.fold<int>(0, (sum, line) => sum + line.amountCents),
      4000,
    );
    expect(
      statement.lines.last.remittance,
      contains('Named unmatched stationery'),
    );
    expect(
      statement.lines.first.bookingDate,
      isNot(statement.lines.first.valueDate),
    );
  });
}

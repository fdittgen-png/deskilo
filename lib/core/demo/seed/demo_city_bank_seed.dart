// SPDX-License-Identifier: AGPL-3.0-or-later
// A fictional statement with two movements awaiting reconciliation.
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../features/money/domain/bank/bank_statement.dart';
import '../data/bank_statement_repository.dart';
import '../data/money_repository.dart';

FakeBankStatementRepository seedCityBankStatement(
  FakeMoneyRepository money,
  DateTime now,
  String city,
  String currency,
) {
  final bank = FakeBankStatementRepository(money: money, today: now);
  final day = DateTime.utc(now.year, now.month, now.day - 1);
  bank.seedStatement(
    BankStatement(
      format: BankFileFormat.camt054,
      account: 'DEMO-$city-ACCOUNT',
      currency: currency,
      statementId: 'DEMO-$city-STATEMENT',
      lines: [
        BankLine(
          position: 1,
          bookingDate: day,
          valueDate: day,
          amountCents: 4200,
          currency: currency,
          transactionId: '$city-receipt',
          counterpartyName: 'Demo visitor',
          remittance: 'Day-use enquiry',
        ),
        BankLine(
          position: 2,
          bookingDate: day,
          valueDate: day,
          amountCents: -1900,
          currency: currency,
          transactionId: '$city-charge',
          counterpartyName: 'Demo bank',
          remittance: 'Monthly banking charge',
        ),
      ],
    ),
    sha256.convert(utf8.encode('demo-bank-$city')).toString(),
    '$city-demo-statement.xml',
  );
  return bank;
}

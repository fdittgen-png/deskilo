// SPDX-License-Identifier: AGPL-3.0-or-later
// test-inventory: pure rules — the invariant is the OFX statement structure
//
// #2380 — an OFX statement is read in both of its syntaxes (1.x SGML with
// unclosed value tags, 2.x XML): the account (bank and card), its currency,
// the ledger balance, and per STMTTRN the posted and user days, signed
// amount, FITID as the bank's id, the payee and memo, and REFNUM as the
// reference when it is a QR or RF reference. A file is refused whole.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/money/domain/bank/bank_file.dart';
import 'package:deskilo/features/money/domain/bank/bank_statement.dart';
import 'package:flutter_test/flutter_test.dart';

const _limits = BankFileLimits(maxBytes: 1 << 20, maxLines: 100);

String _fixture(String name) =>
    File('test/features/money/fixtures/bank/$name').readAsStringSync();

BankStatement _read(String text) => parseBankFile(
  utf8.encode(text),
  format: BankFileFormat.ofx,
  limits: _limits,
);

Matcher _refused(BankFileProblem p) =>
    throwsA(isA<BankFileException>().having((e) => e.problem, 'problem', p));

void main() {
  final text = _fixture('ofx_statement.ofx');
  final s = _read(text);

  test('OFX 1.x: the account, currency and balance', () {
    expect(s.format, BankFileFormat.ofx);
    expect(s.account, '121000248/000123456789');
    expect(s.currency, 'USD');
    expect(s.closingCents, 115550);
    expect(s.openingCents, isNull);
  });

  test('OFX 1.x: each transaction with its fields', () {
    final [qrr, rf, out] = s.lines;
    expect(qrr.bookingDate, DateTime.utc(2026, 1, 15));
    expect(qrr.valueDate, DateTime.utc(2026, 1, 16));
    expect(qrr.amountCents, 12000);
    expect(qrr.transactionId, 'FIT-0001');
    expect(qrr.reference, '210000000003139471430009017');
    expect(qrr.counterpartyName, 'Demo Member One');
    expect(qrr.remittance, 'Invoice 2026-0042');
    expect(rf.reference, 'RF18539007547034');
    expect(rf.counterpartyName, 'Demo Member Two');
    expect(rf.valueDate, rf.bookingDate);
    expect(out.amountCents, -4500);
    expect(out.reference, '');
    expect(out.counterpartyName, 'Demo Supplier & Co');
    expect(s.lines.map((l) => l.position), [1, 2, 3]);
  });

  test('a second read gives the same lines', () {
    expect(
      _read(text).lines.map((l) => l.toJson()),
      s.lines.map((l) => l.toJson()),
    );
  });

  test('OFX 2.x: a card statement in XML', () {
    final card = _read(_fixture('ofx2_statement.ofx'));
    expect(card.account, '4111000000001111');
    expect(card.currency, 'CAD');
    expect(card.closingCents, -1234);
    expect(card.lines.single.amountCents, -1234);
    expect(card.lines.single.transactionId, 'CC-1');
    expect(card.lines.single.counterpartyName, 'Demo Cafe');
  });

  test('two equal transactions with distinct FITIDs stay two', () {
    final twin = _read(
      text
          .replaceFirst('<DTPOSTED>20260120', '<DTPOSTED>20260115')
          .replaceFirst('<TRNAMT>80.50', '<TRNAMT>120.00')
          .replaceFirst(
            '<REFNUM>RF18 5390 0754 7034',
            '<REFNUM>210000000003139471430009017',
          ),
    );
    final [a, b, _] = twin.lines;
    expect(
      (a.bookingDate, a.amountCents, a.reference),
      (b.bookingDate, b.amountCents, b.reference),
    );
    expect(a.transactionId, isNot(b.transactionId));
  });

  group('refusals, one change each', () {
    test('no <OFX>', () {
      expect(
        () => _read(text.replaceAll('<OFX>', '')),
        _refused(BankFileProblem.malformed),
      );
    });
    test('no statement', () {
      expect(
        () => _read(text.replaceAll('STMTRS>', 'STMTXX>')),
        _refused(BankFileProblem.malformed),
      );
    });
    test('a comma radix is read as such, never as a grouper', () {
      final l = _read(text.replaceFirst('<TRNAMT>80.50', '<TRNAMT>-12,50'))
          .lines
          .firstWhere((l) => l.amountCents == -1250);
      expect(l.amountCents, -1250);
      expect(
        () => _read(text.replaceFirst('<TRNAMT>80.50', '<TRNAMT>1,234.50')),
        _refused(BankFileProblem.badAmount),
        reason: 'OFX knows no grouping separator',
      );
    });
    test('an amount that is not one', () {
      expect(
        () => _read(text.replaceFirst('<TRNAMT>80.50', '<TRNAMT>80.5x')),
        _refused(BankFileProblem.badAmount),
      );
    });
    test('a day that is not one', () {
      expect(
        () => _read(
          text.replaceFirst('<DTPOSTED>20260120', '<DTPOSTED>20261320'),
        ),
        _refused(BankFileProblem.badDate),
      );
    });
    test('a currency that is not one', () {
      expect(
        () => _read(text.replaceFirst('<CURDEF>USD', '<CURDEF>US')),
        _refused(BankFileProblem.badCurrency),
      );
    });
    test('no account', () {
      expect(
        () => _read(
          text
              .replaceFirst('<BANKID>121000248', '')
              .replaceFirst('<ACCTID>000123456789', ''),
        ),
        _refused(BankFileProblem.missingAccount),
      );
    });
    test('no transaction', () {
      final i = text.indexOf('<STMTTRN>');
      final j = text.lastIndexOf('</STMTTRN>') + '</STMTTRN>'.length;
      expect(
        () => _read(text.substring(0, i) + text.substring(j)),
        _refused(BankFileProblem.empty),
      );
    });
  });
}

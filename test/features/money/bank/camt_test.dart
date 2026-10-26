// SPDX-License-Identifier: AGPL-3.0-or-later
// test-inventory: pure rules — the invariant is the ISO 20022 camt structure
//
// #2380 — a camt.053 statement and a camt.054 notification are read whole:
// one line per transaction detail with its booking and value days, signed
// amount, bank id, counterparty, structured reference (QRR, RF), end-to-end
// id and remittance; pending entries are not movements; the balances are
// read; a file is refused whole, with the problem named, never kept in part.
// SIX's published camt.054 sample reads too.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/money/domain/bank/bank_file.dart';
import 'package:deskilo/features/money/domain/bank/bank_statement.dart';
import 'package:flutter_test/flutter_test.dart';

const _limits = BankFileLimits(maxBytes: 1 << 20, maxLines: 100);

String _fixture(String name) =>
    File('test/features/money/fixtures/bank/$name').readAsStringSync();

BankStatement _read(String text, BankFileFormat format) =>
    parseBankFile(utf8.encode(text), format: format, limits: _limits);

Matcher _refused(BankFileProblem p) =>
    throwsA(isA<BankFileException>().having((e) => e.problem, 'problem', p));

void main() {
  group('camt.053', () {
    final text = _fixture('camt053_statement.xml');
    final s = _read(text, BankFileFormat.camt053);

    test('the account, currency, balances and statement id', () {
      expect(s.format, BankFileFormat.camt053);
      expect(s.account, 'CH9300762011623852957');
      expect(s.currency, 'CHF');
      expect(s.statementId, 'STMT-2026-01');
      expect(s.openingCents, 100000);
      expect(s.closingCents, 115550);
      expect(s.from, DateTime.utc(2026, 1, 15));
      expect(s.to, DateTime.utc(2026, 1, 22));
    });

    test('three booked lines, the pending entry left out', () {
      expect(s.lines, hasLength(3));
      final [qrr, rf, out] = s.lines;
      expect(qrr.position, 1);
      expect(qrr.bookingDate, DateTime.utc(2026, 1, 15));
      expect(qrr.valueDate, DateTime.utc(2026, 1, 16));
      expect(qrr.amountCents, 12000);
      expect(qrr.currency, 'CHF');
      expect(qrr.transactionId, 'BANK-0001');
      expect(qrr.counterpartyName, 'Demo Member One');
      expect(qrr.counterpartyIban, 'CH5604835012345678009');
      expect(qrr.reference, '210000000003139471430009017');
      expect(qrr.endToEndId, 'E2E-0001');
      expect(qrr.remittance, 'Invoice 2026-0042');
      expect(rf.reference, 'RF18539007547034');
      expect(rf.counterpartyName, 'Demo Member Two');
      final odd = _read(
        _fixture('camt053_statement.xml').replaceFirst(
          '<Ref>RF18 5390 0754 7034</Ref>',
          '<Ref>ORDER-77</Ref>',
        ),
        BankFileFormat.camt053,
      ).lines[1];
      expect(odd.reference, '', reason: 'not a QR or RF reference');
      expect(odd.remittance, startsWith('ORDER-77'));
      expect(rf.amountCents, 8050);
      expect(out.amountCents, -4500);
      expect(out.reference, '');
      expect(out.endToEndId, '', reason: 'NOTPROVIDED is no id');
      expect(out.counterpartyName, 'Demo Supplier');
      expect(out.counterpartyIban, 'CH4431999123000889012');
      expect(out.remittance, 'Office supplies January');
    });

    test('a second read gives the same lines', () {
      final again = _read(text, BankFileFormat.camt053);
      expect(
        again.lines.map((l) => l.toJson()),
        s.lines.map((l) => l.toJson()),
      );
    });

    test('read as camt.054 it is refused as malformed', () {
      expect(
        () => _read(text, BankFileFormat.camt054),
        _refused(BankFileProblem.malformed),
      );
    });
  });

  group('camt.054', () {
    final s = _read(
      _fixture('camt054_notification.xml'),
      BankFileFormat.camt054,
    );

    test('a batch entry is one line per payment, each with its reference', () {
      expect(s.statementId, 'NTF-2026-0115');
      expect(s.lines.map((l) => l.amountCents), [12000, 8050, 3000]);
      expect(s.lines.map((l) => l.reference), [
        '210000000003139471430009017',
        'RF18539007547034',
        '',
      ]);
      expect(s.lines.map((l) => l.transactionId), [
        'BATCH-7/1',
        'BATCH-7/2',
        'BANK-0099',
      ]);
      expect(s.lines.map((l) => l.position), [1, 2, 3]);
      expect(s.lines.first.bookingDate, DateTime.utc(2026, 1, 15));
      expect(s.lines.first.endToEndId, 'E2E-QRR');
      expect(s.lines.last.remittance, 'Coffee card');
      expect(s.lines.last.counterpartyName, 'Demo Guest');
    });

    test('the published SIX sample reads as one debit', () {
      final six = _read(
        _fixture('six_rtgs_camt_054_sample.xml'),
        BankFileFormat.camt054,
      );
      expect(six.account, '082310');
      expect(six.currency, 'CHF');
      expect(six.lines, hasLength(1));
      final l = six.lines.single;
      expect(l.amountCents, -100050);
      expect(l.bookingDate, DateTime.utc(2025, 12, 17));
      expect(l.valueDate, DateTime.utc(2028, 12, 17));
      expect(
        l.transactionId,
        '07be0a8e-4a63-45cb-8258-59ffb215b8a3',
        reason: 'without an AcctSvcrRef the UETR names the movement',
      );
      expect(l.reference, '');
    });
  });

  group('refusals, one change each', () {
    final text = _fixture('camt053_statement.xml');

    test('a broken document', () {
      expect(
        () => _read(text.replaceFirst('</Stmt>', ''), BankFileFormat.camt053),
        _refused(BankFileProblem.malformed),
      );
    });
    test('a document type', () {
      expect(
        () => _read(
          text.replaceFirst('<Document', '<!DOCTYPE Document>\n<Document'),
          BankFileFormat.camt053,
        ),
        _refused(BankFileProblem.malformed),
      );
    });
    test('a comma in an amount', () {
      expect(
        () => _read(
          text.replaceFirst(
            '<Amt Ccy="CHF">80.50</Amt>',
            '<Amt Ccy="CHF">80,50</Amt>',
          ),
          BankFileFormat.camt053,
        ),
        _refused(BankFileProblem.badAmount),
      );
    });
    test('an amount with a third decimal', () {
      expect(
        () => _read(
          text.replaceFirst(
            '<Amt Ccy="CHF">80.50</Amt>',
            '<Amt Ccy="CHF">80.505</Amt>',
          ),
          BankFileFormat.camt053,
        ),
        _refused(BankFileProblem.badAmount),
      );
    });
    test('a day that is not one', () {
      expect(
        () => _read(
          text.replaceFirst(
            '<Dt>2026-01-20</Dt></BookgDt>',
            '<Dt>2026-02-30</Dt></BookgDt>',
          ),
          BankFileFormat.camt053,
        ),
        _refused(BankFileProblem.badDate),
      );
    });
    test('no account', () {
      expect(
        () => _read(
          text.replaceFirst('<IBAN>CH93 0076 2011 6238 5295 7</IBAN>', ''),
          BankFileFormat.camt053,
        ),
        _refused(BankFileProblem.missingAccount),
      );
    });
    test('a line in another currency', () {
      expect(
        () => _read(
          text.replaceFirst(
            '<Amt Ccy="CHF">45.00</Amt>',
            '<Amt Ccy="EUR">45.00</Amt>',
          ),
          BankFileFormat.camt053,
        ),
        _refused(BankFileProblem.badCurrency),
      );
    });
    test('only a pending entry', () {
      final pendingOnly = text.replaceAll('<Cd>BOOK</Cd>', '<Cd>PDNG</Cd>');
      expect(
        () => _read(pendingOnly, BankFileFormat.camt053),
        _refused(BankFileProblem.empty),
      );
    });
    test('a second account in the same file', () {
      final i = text.indexOf('<Stmt>');
      final j = text.indexOf('</Stmt>') + '</Stmt>'.length;
      final other = text
          .substring(i, j)
          .replaceFirst('CH93 0076 2011 6238 5295 7', 'CH5604835012345678009');
      expect(
        () => _read(
          text.replaceFirst('</Stmt>', '</Stmt>$other'),
          BankFileFormat.camt053,
        ),
        _refused(BankFileProblem.malformed),
      );
    });
  });

  test('two movements equal in day, amount and reference stay two', () {
    final text = _fixture('camt053_statement.xml');
    final twin = text
        .replaceFirst(
          '<Amt Ccy="CHF">80.50</Amt>',
          '<Amt Ccy="CHF">120.00</Amt>',
        )
        .replaceFirst(
          '<Dt>2026-01-20</Dt></BookgDt>',
          '<Dt>2026-01-15</Dt></BookgDt>',
        )
        .replaceFirst('RF18 5390 0754 7034', '210000000003139471430009017');
    final [a, b, _] = _read(twin, BankFileFormat.camt053).lines;
    expect(
      (a.bookingDate, a.amountCents, a.reference),
      (b.bookingDate, b.amountCents, b.reference),
    );
    expect(a.transactionId, isNot(b.transactionId));
  });
}

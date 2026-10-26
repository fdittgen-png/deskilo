// SPDX-License-Identifier: AGPL-3.0-or-later
// test-inventory: pure rules — the invariant is the SWIFT MT940 structure
//
// #2380 — an MT940 statement is read whole: `:25:` the account, `:60F:` and
// `:62F:` the balances, each `:61:` a movement with its value and entry
// days (the entry year taken nearest the value day), sign, amount and bank
// reference, its `:86:` read as free text or as the German SEPA subfields;
// a QR or RF reference is taken from the remittance only when its check
// digits hold. A file is refused whole, with the problem named.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/money/domain/bank/bank_file.dart';
import 'package:deskilo/features/money/domain/bank/bank_statement.dart';
import 'package:flutter_test/flutter_test.dart';

const _limits = BankFileLimits(maxBytes: 1 << 20, maxLines: 100);

final _text = File('test/features/money/fixtures/bank/mt940_statement.sta')
    .readAsStringSync();

BankStatement _read(String text) => parseBankFile(
  utf8.encode(text),
  format: BankFileFormat.mt940,
  limits: _limits,
);

Matcher _refused(BankFileProblem p) =>
    throwsA(isA<BankFileException>().having((e) => e.problem, 'problem', p));

void main() {
  final s = _read(_text);

  test('the account, currency and balances', () {
    expect(s.account, 'DE89370400440532013000');
    expect(s.currency, 'EUR');
    expect(s.statementId, 'STARTUMS');
    expect(s.openingCents, 100000);
    expect(s.closingCents, 115550);
  });

  test('each movement with its fields', () {
    final [sepa, free, out] = s.lines;
    expect(sepa.valueDate, DateTime.utc(2026, 1, 15));
    expect(sepa.bookingDate, DateTime.utc(2026, 1, 15));
    expect(sepa.amountCents, 12000);
    expect(sepa.currency, 'EUR');
    expect(sepa.transactionId, 'BANK-0001');
    expect(sepa.endToEndId, 'E2E-0001');
    expect(sepa.counterpartyIban, 'CH5604835012345678009');
    expect(sepa.counterpartyName, 'Demo Member One');
    expect(sepa.reference, '210000000003139471430009017');
    expect(sepa.remittance, 'Invoice 2026-0042 2100000000031394714300090 17');
    expect(free.bookingDate, DateTime.utc(2026, 1, 20));
    expect(free.amountCents, 8050);
    expect(free.reference, 'RF18539007547034');
    expect(free.remittance, 'Payment RF18 5390 0754 7034 Demo Member Two');
    expect(out.amountCents, -4500);
    expect(out.reference, '');
    expect(out.transactionId, 'BANK-0003');
    expect(s.lines.map((l) => l.position), [1, 2, 3]);
  });

  test('a second read gives the same lines', () {
    expect(
      _read(_text).lines.map((l) => l.toJson()),
      s.lines.map((l) => l.toJson()),
    );
  });

  test('an entry day across the year end belongs to the year before', () {
    final l = _read(_text.replaceFirst(':61:2601150115CR', ':61:2601021231CR'))
        .lines
        .first;
    expect(l.valueDate, DateTime.utc(2026, 1, 2));
    expect(l.bookingDate, DateTime.utc(2025, 12, 31));
  });

  test('a reversal of a debit is money in', () {
    final l = _read(_text.replaceFirst('0122D45,00', '0122RD45,00')).lines.last;
    expect(l.amountCents, 4500);
  });

  test('a slash inside the owner reference is part of it', () {
    final l = _read(
      _text.replaceFirst(
        ':61:260120C80,50NTRFNONREF//BANK-0002',
        ':61:260120C80,50NMSCTRF/12345//BANK-3',
      ),
    ).lines[1];
    expect(l.amountCents, 8050);
    expect(l.transactionId, 'BANK-3');
  });

  test('a reference with a wrong check digit is free text', () {
    final l = _read(_text.replaceFirst('RF18 5390', 'RF19 5390')).lines[1];
    expect(l.reference, '');
  });

  test('two equal movements with distinct bank references stay two', () {
    final twin = _read(
      _text.replaceFirst(
        ':61:260120C80,50NTRFNONREF//BANK-0002',
        ':61:2601150115CR120,00NTRFNONREF//BANK-0002',
      ),
    );
    final [a, b, _] = twin.lines;
    expect((a.bookingDate, a.amountCents), (b.bookingDate, b.amountCents));
    expect(a.transactionId, isNot(b.transactionId));
  });

  group('refusals, one change each', () {
    test('a movement line of the wrong shape', () {
      expect(
        () => _read(_text.replaceFirst(':61:260120C80,50', ':61:260120X80,50')),
        _refused(BankFileProblem.malformed),
      );
    });
    test('no :20:', () {
      expect(
        () => _read(_text.replaceFirst(':20:STARTUMS', ':21:STARTUMS')),
        _refused(BankFileProblem.malformed),
      );
    });
    test('a day that is not one', () {
      expect(
        () => _read(_text.replaceFirst(':61:260120C', ':61:260230C')),
        _refused(BankFileProblem.badDate),
      );
    });
    test('an amount with a third decimal', () {
      expect(
        () => _read(_text.replaceFirst('C80,50', 'C80,505')),
        _refused(BankFileProblem.badAmount),
      );
    });
    test('an empty account', () {
      expect(
        () => _read(
          _text.replaceFirst(':25:DE89 3704 0044 0532 0130 00', ':25:'),
        ),
        _refused(BankFileProblem.missingAccount),
      );
    });
    test('a second account', () {
      expect(
        () => _read(
          '$_text:20:NEXT\r\n:25:CH9300762011623852957\r\n:60F:C260122EUR1155,50\r\n',
        ),
        _refused(BankFileProblem.malformed),
      );
    });
    test('no movement', () {
      final i = _text.indexOf(':61:');
      final j = _text.indexOf(':62F:');
      expect(
        () => _read(_text.substring(0, i) + _text.substring(j)),
        _refused(BankFileProblem.empty),
      );
    });
  });
}

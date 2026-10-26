// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Febelfin CODA 2.x, the Belgian coded statement: fixed 128-character
// records — 0 header, 1 old balance (the account and its currency), 21/22/23
// one movement and its counterparty, 31/32/33 information, 8 new balance,
// 9 trailer. Amounts carry three decimals; the third must be zero for a
// currency of two. A globalised batch (a total followed by its details
// under the same sequence number) is read as its details, never as the
// total and the details both. The Belgian structured communication
// (+++123/4567/89012+++, type 101) is the reference as its 12 digits.
// Positions below are the specification's 1-based ones. Pure Dart.
import 'bank_statement.dart';
import 'bank_values.dart';
import 'structured_reference.dart';

/// Every CODA record is this long.
const int _recordLength = 128;

/// The century a two-digit CODA year falls in.
const int _century = 2000;

/// The structured communication types that carry the Belgian 12-digit
/// reference (OGM/VCS).
const Set<String> _ogmTypes = {'101', '102'};

/// The statement a CODA [text] carries.
BankStatement readCoda(String text) {
  final records = <(int, String)>[];
  for (final (i, raw) in text.split(RegExp(r'\r?\n')).indexed) {
    final r = raw.trimRight();
    if (r.isEmpty) continue;
    if (r.length > _recordLength || !RegExp(r'^[0-9]').hasMatch(r)) {
      throw BankFileException(
        BankFileProblem.malformed,
        line: i + 1,
        detail: 'not a CODA record',
      );
    }
    records.add((i + 1, r.padRight(_recordLength)));
  }
  if (records.isEmpty || records.first.$2[0] != '0') {
    throw const BankFileException(
      BankFileProblem.malformed,
      detail: 'no header record',
    );
  }
  String? account;
  String? currency;
  int? opening;
  int? closing;
  final movements = <_Movement>[];
  for (final (line, r) in records) {
    switch (r.substring(0, 2)) {
      case '10' || '11' || '12' || '13':
        final (number, ccy) = _accountOf(r, line);
        if (account != null && number != account) {
          throw BankFileException(
            BankFileProblem.malformed,
            line: line,
            detail: 'several accounts in one file',
          );
        }
        account = number;
        currency ??= ccy;
        opening ??= _balance(_p(r, 43, 43), _p(r, 44, 58), ccy, line);
      case '21':
        if (currency == null) {
          throw BankFileException(
            BankFileProblem.malformed,
            line: line,
            detail: 'a movement before its old balance',
          );
        }
        movements.add(_Movement.of(r, line, currency));
      case '22':
        _continued(movements, r, line).part2(r);
      case '23':
        _continued(movements, r, line).part3(r);
      case '80' ||
          '81' ||
          '82' ||
          '83' ||
          '84' ||
          '85' ||
          '86' ||
          '87' ||
          '88' ||
          '89':
        closing = _balance(_p(r, 42, 42), _p(r, 43, 57), currency ?? '', line);
    }
  }
  // A sequence with details is read as its details; its total is dropped.
  final detailed = {
    for (final m in movements)
      if (m.detail > 0) m.sequence,
  };
  final kept = movements
      .where((m) => m.detail > 0 || !detailed.contains(m.sequence))
      .toList();
  return BankStatement(
    format: BankFileFormat.coda,
    account: account ?? '',
    currency: currency ?? '',
    openingCents: opening,
    closingCents: closing,
    lines: [for (final (i, m) in kept.indexed) m.line(i + 1)],
  );
}

String _p(String r, int from, int to) => r.substring(from - 1, to);

(String, String) _accountOf(String r, int line) {
  final structure = r[1];
  final (raw, ccy) = switch (structure) {
    '0' => (_p(r, 6, 17), _p(r, 19, 21)),
    _ => (_p(r, 6, 39), _p(r, 40, 42)),
  };
  final number = raw.trim();
  return (
    structure == '2' || structure == '3' ? compactIban(number) : number,
    bankCurrency(ccy, line: line),
  );
}

int _balance(String sign, String digits, String currency, int line) {
  final cents = _amount(digits, currency, line);
  return sign == '1' ? -cents : cents;
}

int _amount(String digits, String currency, int line) {
  if (!RegExp(r'^\d{15}$').hasMatch(digits)) {
    throw BankFileException(
      BankFileProblem.badAmount,
      line: line,
      detail: digits,
    );
  }
  return bankAmount(
    '${digits.substring(0, 12)}.${digits.substring(12)}',
    bankCurrency(currency, line: line),
    line: line,
  );
}

DateTime _date(String ddmmyy, int line) {
  if (!RegExp(r'^\d{6}$').hasMatch(ddmmyy)) {
    throw BankFileException(
      BankFileProblem.badDate,
      line: line,
      detail: ddmmyy,
    );
  }
  return bankDay(
    _century + int.parse(ddmmyy.substring(4)),
    int.parse(ddmmyy.substring(2, 4)),
    int.parse(ddmmyy.substring(0, 2)),
    line: line,
  );
}

_Movement _continued(List<_Movement> movements, String r, int line) {
  if (movements.isEmpty || movements.last.sequence != _p(r, 3, 6)) {
    throw BankFileException(
      BankFileProblem.malformed,
      line: line,
      detail: 'a continuation without its movement',
    );
  }
  return movements.last;
}

class _Movement {
  _Movement({
    required this.sequence,
    required this.detail,
    required this.bankRef,
    required this.cents,
    required this.value,
    required this.booking,
    required this.currency,
    required this.structured,
    required this.communication,
  });

  factory _Movement.of(String r, int line, String currency) {
    final cents = _amount(_p(r, 33, 47), currency, line);
    final structured = _p(r, 62, 62) == '1';
    final value = _date(_p(r, 48, 53), line);
    final entry = _p(r, 116, 121);
    return _Movement(
      sequence: _p(r, 3, 6),
      detail: int.tryParse(_p(r, 7, 10)) ?? 0,
      bankRef: _p(r, 11, 31).trim(),
      cents: _p(r, 32, 32) == '1' ? -cents : cents,
      value: value,
      booking: entry.trim().isEmpty || entry == '000000'
          ? value
          : _date(entry, line),
      currency: currency,
      structured: structured,
      communication: _p(r, 63, 115),
    );
  }

  final String sequence;
  final int detail;
  final String bankRef;
  final int cents;
  final DateTime value;
  final DateTime booking;
  final String currency;
  final bool structured;
  String communication;
  String counterpartyAccount = '';
  String counterpartyName = '';
  String more = '';

  void part2(String r) {
    communication += _p(r, 11, 63);
  }

  void part3(String r) {
    counterpartyAccount = _p(r, 11, 44).trim();
    counterpartyName = _p(r, 48, 82).trim();
    more = _p(r, 83, 125);
  }

  BankLine line(int position) {
    var reference = '';
    var remittance = '';
    if (structured) {
      final type = communication.substring(0, 3);
      final body = communication.substring(3);
      if (_ogmTypes.contains(type)) {
        // The Belgian structured communication is not a QR or RF
        // reference: kept as text, where the number scan still reads it.
        remittance = body.substring(0, 12).trim();
      } else {
        reference = structuredReferenceIn(body) ?? '';
        remittance = body.trim();
      }
    } else {
      remittance = '$communication$more'.replaceAll(RegExp(r'\s+'), ' ').trim();
      reference = structuredReferenceIn(remittance) ?? '';
    }
    return BankLine(
      position: position,
      bookingDate: booking,
      valueDate: value,
      amountCents: cents,
      currency: currency,
      transactionId: detail > 0 ? '$bankRef/$detail' : bankRef,
      counterpartyName: counterpartyName,
      counterpartyIban: RegExp(r'^[A-Z]{2}\d{2}').hasMatch(counterpartyAccount)
          ? compactIban(counterpartyAccount)
          : counterpartyAccount,
      reference: normalizeReference(reference),
      remittance: remittance,
    );
  }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// SWIFT MT940, the customer statement still exported by most banks beside
// camt: `:25:` the account, `:60F:`/`:62F:` the balances, one `:61:` per
// movement with the `:86:` that follows it. The `:86:` is free text, or the
// German SEPA structure (`?20`–`?29` the remittance, `?31` the IBAN,
// `?32`/`?33` the name, `EREF+` the end-to-end id). A structured reference
// is read out of the remittance only when its check digits hold. Several
// statements of one account in one file are read as one. Pure Dart.
import 'bank_statement.dart';
import 'bank_values.dart';
import 'structured_reference.dart';

final _tag = RegExp(r'^:(\d{2}[A-Z]?):');
final _f61 = RegExp(
  r'^(\d{2})(\d{2})(\d{2})(\d{2}\d{2})?(R?[CD])([A-Z])?(\d+,\d*)([NFS][A-Z0-9]{3})([^/]*?)(?://(.*))?$',
);
final _balance = RegExp(r'^([CD])(\d{2})(\d{2})(\d{2})([A-Z]{3})(\d+,\d*)$');

/// The century a two-digit MT940 year falls in.
const int _century = 2000;

/// The statement an MT940 [text] carries.
BankStatement readMt940(String text) {
  final fields = _fieldsOf(text);
  if (!fields.any((f) => f.tag == '20') || !fields.any((f) => f.tag == '25')) {
    throw const BankFileException(
      BankFileProblem.malformed,
      detail: 'no :20: or :25:',
    );
  }
  String? account;
  String? currency;
  int? opening;
  int? closing;
  final ids = <String>[];
  final lines = <BankLine>[];
  _Pending? pending;
  void flush() {
    if (pending != null) lines.add(pending!.line(lines.length + 1, currency!));
    pending = null;
  }

  for (final f in fields) {
    switch (f.tag) {
      case '20':
        flush();
        ids.add(f.value.trim());
      case '25':
        final raw = f.value.trim();
        final number = RegExp(r'^[A-Za-z]{2}\d{2}').hasMatch(raw)
            ? compactIban(raw)
            : raw;
        if (account != null && number != account) {
          throw BankFileException(
            BankFileProblem.malformed,
            line: f.line,
            detail: 'several accounts in one file',
          );
        }
        account = number;
      case '60F' || '60M':
        final b = _balanceOf(f);
        currency ??= b.currency;
        opening ??= b.cents;
      case '62F' || '62M':
        flush();
        closing = _balanceOf(f).cents;
      case '61':
        flush();
        if (currency == null) {
          throw BankFileException(
            BankFileProblem.malformed,
            line: f.line,
            detail: 'a movement before its opening balance',
          );
        }
        pending = _movementOf(f, currency);
      case '86':
        pending?.info = f.value;
    }
  }
  flush();
  return BankStatement(
    format: BankFileFormat.mt940,
    account: account ?? '',
    currency: currency ?? '',
    statementId: ids.where((i) => i.isNotEmpty).join('+'),
    openingCents: opening,
    closingCents: closing,
    lines: lines,
  );
}

class _Field {
  _Field(this.tag, this.value, this.line);
  final String tag;
  String value;
  final int line;
}

List<_Field> _fieldsOf(String text) {
  // A SWIFT envelope ({1:…}{2:…}{4:) and its trailer (-}) are not fields.
  final body = text
      .replaceAll(RegExp(r'\{[1-3]:[^}]*\}'), '')
      .replaceAll('{4:', '');
  final out = <_Field>[];
  for (final (i, raw) in body.split(RegExp(r'\r?\n')).indexed) {
    final line = raw.trimRight();
    if (line.isEmpty || line == '-' || line == '-}' || line == '}') continue;
    final m = _tag.firstMatch(line);
    if (m != null) {
      out.add(_Field(m.group(1)!, line.substring(m.end), i + 1));
    } else if (out.isNotEmpty) {
      out.last.value += '\n$line';
    } else {
      throw BankFileException(
        BankFileProblem.malformed,
        line: i + 1,
        detail: 'text before the first field',
      );
    }
  }
  return out;
}

({String currency, int cents}) _balanceOf(_Field f) {
  final m = _balance.firstMatch(f.value.trim());
  if (m == null) {
    throw BankFileException(
      BankFileProblem.malformed,
      line: f.line,
      detail: 'balance :${f.tag}:',
    );
  }
  bankDay(
    _century + int.parse(m.group(2)!),
    int.parse(m.group(3)!),
    int.parse(m.group(4)!),
    line: f.line,
  );
  final currency = bankCurrency(m.group(5)!, line: f.line);
  final cents = bankAmount(
    m.group(6)!,
    currency,
    line: f.line,
    decimalSeparator: ',',
  );
  return (currency: currency, cents: m.group(1) == 'D' ? -cents : cents);
}

class _Pending {
  _Pending(this.booking, this.value, this.cents, this.bankRef);
  final DateTime booking;
  final DateTime value;
  final int cents;
  final String bankRef;
  String info = '';

  BankLine line(int position, String currency) {
    final i = _infoOf(info);
    return BankLine(
      position: position,
      bookingDate: booking,
      valueDate: value,
      amountCents: cents,
      currency: currency,
      transactionId: bankRef,
      counterpartyName: i.name,
      counterpartyIban: i.iban,
      reference: structuredReferenceIn(i.text) ?? '',
      endToEndId: i.endToEnd,
      remittance: i.text,
    );
  }
}

_Pending _movementOf(_Field f, String currency) {
  final first = f.value.split('\n').first.trim();
  final m = _f61.firstMatch(first);
  if (m == null) {
    throw BankFileException(
      BankFileProblem.malformed,
      line: f.line,
      detail: ':61: $first',
    );
  }
  final value = bankDay(
    _century + int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
    line: f.line,
  );
  var booking = value;
  final entry = m.group(4);
  if (entry != null) {
    final month = int.parse(entry.substring(0, 2));
    final day = int.parse(entry.substring(2));
    // The entry day carries no year: the one nearest the value day.
    final year = month == 12 && value.month == 1
        ? value.year - 1
        : month == 1 && value.month == 12
        ? value.year + 1
        : value.year;
    booking = bankDay(year, month, day, line: f.line);
  }
  final mark = m.group(5)!;
  final cents = bankAmount(
    m.group(7)!,
    currency,
    line: f.line,
    decimalSeparator: ',',
  );
  final credit = mark == 'C' || mark == 'RD';
  return _Pending(
    booking,
    value,
    credit ? cents : -cents,
    (m.group(10) ?? '').trim(),
  );
}

final _subfield = RegExp(r'\?(\d{2})');
final _sepaTag = RegExp(
  r'(EREF|KREF|MREF|CRED|DEBT|SVWZ|ABWA|ABWE|IBAN|BIC)\+',
);

({String text, String name, String iban, String endToEnd}) _infoOf(String raw) {
  final joined = raw.replaceAll('\n', '');
  if (!joined.contains('?2')) {
    return (
      text: raw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .join(' '),
      name: '',
      iban: '',
      endToEnd: '',
    );
  }
  final parts = <String, String>{};
  final marks = _subfield.allMatches(joined).toList();
  for (final (i, m) in marks.indexed) {
    final end = i + 1 < marks.length ? marks[i + 1].start : joined.length;
    parts[m.group(1)!] = joined.substring(m.end, end);
  }
  final remittance = [
    for (var n = 20; n <= 29; n++) parts['$n'] ?? '',
    for (var n = 60; n <= 63; n++) parts['$n'] ?? '',
  ].join();
  var endToEnd = '';
  var text = remittance;
  final tags = _sepaTag.allMatches(remittance).toList();
  if (tags.isNotEmpty) {
    final values = <String, String>{};
    for (final (i, t) in tags.indexed) {
      final end = i + 1 < tags.length ? tags[i + 1].start : remittance.length;
      values[t.group(1)!] = remittance.substring(t.end, end).trim();
    }
    endToEnd = values['EREF'] ?? '';
    if (endToEnd == 'NOTPROVIDED') endToEnd = '';
    text = values['SVWZ'] ?? remittance;
  }
  return (
    text: text.trim(),
    name: '${parts['32'] ?? ''}${parts['33'] ?? ''}'.trim(),
    iban: compactIban(parts['31'] ?? ''),
    endToEnd: endToEnd,
  );
}

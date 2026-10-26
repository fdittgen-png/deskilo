// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ISO 20022 cash-management messages: camt.053 (BankToCustomerStatement)
// and camt.054 (BankToCustomerDebitCreditNotification), of any version —
// the message is recognised by its element names, never by the namespace's
// version. One line per transaction detail: a batch entry of three
// payments is three lines, each with its own reference. Only booked entries
// are movements; pending and information entries are not. One file is one
// account: several statements of the same account are read as one, of
// different accounts refused. Pure Dart.
import 'package:xml/xml.dart';

import 'bank_statement.dart';
import 'bank_values.dart';
import 'structured_reference.dart';

/// The message root of each camt format and the element of one report.
const Map<BankFileFormat, (String, String)> _roots = {
  BankFileFormat.camt053: ('BkToCstmrStmt', 'Stmt'),
  BankFileFormat.camt054: ('BkToCstmrDbtCdtNtfctn', 'Ntfctn'),
};

/// The statement [doc] carries as [format].
BankStatement readCamt(XmlDocument doc, BankFileFormat format) {
  final (root, report) = _roots[format]!;
  final message = doc.rootElement.childElements.firstOrNull;
  if (doc.rootElement.name.local != 'Document' ||
      message == null ||
      message.name.local != root) {
    throw const BankFileException(
      BankFileProblem.malformed,
      detail: 'not this camt message',
    );
  }
  final reports = _kids(message, report).toList();
  if (reports.isEmpty) {
    throw const BankFileException(
      BankFileProblem.malformed,
      detail: 'no report',
    );
  }
  String? account;
  String? currency;
  final ids = <String>[];
  int? opening;
  int? closing;
  final lines = <BankLine>[];
  for (final r in reports) {
    final acct = _at(r, ['Acct']);
    final iban = _text(acct, ['Id', 'IBAN']);
    final number = iban.isNotEmpty
        ? compactIban(iban)
        : _text(acct, ['Id', 'Othr', 'Id']);
    if (account != null && number != account) {
      throw const BankFileException(
        BankFileProblem.malformed,
        detail: 'several accounts in one file',
      );
    }
    account = number;
    final ccy = _text(acct, ['Ccy']);
    currency ??= ccy.isEmpty ? null : bankCurrency(ccy);
    final id = _text(r, ['Id']);
    if (id.isNotEmpty) ids.add(id);
    for (final bal in _kids(r, 'Bal')) {
      final code = _text(bal, ['Tp', 'CdOrPrtry', 'Cd']);
      if (code == 'OPBD' || code == 'PRCD') {
        opening ??= _signed(bal, currency);
      } else if (code == 'CLBD') {
        closing = _signed(bal, currency);
      }
    }
    for (final entry in _kids(r, 'Ntry')) {
      if (!_booked(entry)) continue;
      currency ??= bankCurrency(
        _at(entry, ['Amt'])?.getAttribute('Ccy') ?? '',
        line: lines.length + 1,
      );
      lines.addAll(_linesOf(entry, currency, lines.length));
    }
  }
  return BankStatement(
    format: format,
    account: account ?? '',
    currency: currency ?? '',
    statementId: ids.join('+'),
    openingCents: opening,
    closingCents: closing,
    lines: lines,
  );
}

bool _booked(XmlElement entry) {
  final sts = _at(entry, ['Sts']);
  if (sts == null) return true;
  final code = sts.childElements.isEmpty
      ? sts.innerText.trim()
      : _text(sts, ['Cd']);
  return code.isEmpty || code == 'BOOK';
}

List<BankLine> _linesOf(XmlElement entry, String currency, int before) {
  final position = before + 1;
  final entrySign = _text(entry, ['CdtDbtInd']);
  final booking = _day(entry, 'BookgDt', position);
  final value = _day(entry, 'ValDt', position);
  if (booking == null && value == null) {
    throw BankFileException(
      BankFileProblem.badDate,
      line: position,
      detail: 'no booking or value date',
    );
  }
  final entryAmount = _at(entry, ['Amt']);
  final entryCcy = entryAmount?.getAttribute('Ccy');
  final details = [
    for (final d in _kids(entry, 'NtryDtls')) ..._kids(d, 'TxDtls'),
  ];
  final entryRef = _text(entry, ['AcctSvcrRef']).isNotEmpty
      ? _text(entry, ['AcctSvcrRef'])
      : _text(entry, ['NtryRef']);
  if (details.isEmpty) {
    return [
      BankLine(
        position: position,
        bookingDate: booking ?? value!,
        valueDate: value ?? booking!,
        amountCents: _amount(
          entryAmount,
          entrySign,
          entryCcy,
          currency,
          position,
        ),
        currency: entryCcy == null
            ? currency
            : bankCurrency(entryCcy, line: position),
        transactionId: entryRef,
      ),
    ];
  }
  return [
    for (final (i, tx) in details.indexed)
      _detailLine(
        tx,
        position: position + i,
        entry: (
          booking: booking ?? value!,
          value: value ?? booking!,
          sign: entrySign,
          currency: currency,
        ),
        entryAmount: details.length == 1 ? entryAmount : null,
        entryRef: details.length == 1 || entryRef.isEmpty
            ? entryRef
            : '$entryRef/${i + 1}',
      ),
  ];
}

/// What a transaction detail inherits from its entry.
typedef _Entry = ({
  DateTime booking,
  DateTime value,
  String sign,
  String currency,
});

BankLine _detailLine(
  XmlElement tx, {
  required int position,
  required _Entry entry,
  required XmlElement? entryAmount,
  required String entryRef,
}) {
  final (:booking, :value, sign: entrySign, :currency) = entry;
  final amt =
      _at(tx, ['Amt']) ?? _at(tx, ['AmtDtls', 'TxAmt', 'Amt']) ?? entryAmount;
  if (amt == null) {
    throw BankFileException(
      BankFileProblem.badAmount,
      line: position,
      detail: 'a batch detail without its amount',
    );
  }
  final ownSign = _text(tx, ['CdtDbtInd']);
  final sign = ownSign.isEmpty ? entrySign : ownSign;
  final ccy = amt.getAttribute('Ccy');
  final cents = _amount(amt, sign, ccy, currency, position);
  final party = cents < 0 ? 'Cdtr' : 'Dbtr';
  final parties = _at(tx, ['RltdPties']);
  final name = _text(parties, [party, 'Nm']).isNotEmpty
      ? _text(parties, [party, 'Nm'])
      : _text(parties, [party, 'Pty', 'Nm']);
  final rmt = _at(tx, ['RmtInf']);
  final structured = [
    for (final s in _kids(rmt, 'Strd')) _text(s, ['CdtrRefInf', 'Ref']),
  ].where((r) => r.isNotEmpty);
  final endToEnd = _text(tx, ['Refs', 'EndToEndId']);
  final ownRef = _text(tx, ['Refs', 'AcctSvcrRef']);
  return BankLine(
    position: position,
    bookingDate: booking,
    valueDate: value,
    amountCents: cents,
    currency: ccy == null ? currency : bankCurrency(ccy, line: position),
    transactionId: ownRef.isNotEmpty ? ownRef : entryRef,
    counterpartyName: name,
    counterpartyIban: compactIban(
      _text(parties, ['${party}Acct', 'Id', 'IBAN']),
    ),
    reference: structured.isEmpty ? '' : normalizeReference(structured.first),
    endToEndId: endToEnd == 'NOTPROVIDED' ? '' : endToEnd,
    remittance: [for (final u in _kids(rmt, 'Ustrd')) u.innerText.trim()]
        .where((t) => t.isNotEmpty)
        .join(' '),
  );
}

int _amount(
  XmlElement? amt,
  String sign,
  String? ccy,
  String currency,
  int position,
) {
  if (amt == null) {
    throw BankFileException(BankFileProblem.badAmount, line: position);
  }
  if (sign != 'CRDT' && sign != 'DBIT') {
    throw BankFileException(
      BankFileProblem.badAmount,
      line: position,
      detail: 'credit or debit: $sign',
    );
  }
  final cents = bankAmount(
    amt.innerText,
    ccy == null ? currency : bankCurrency(ccy, line: position),
    line: position,
  );
  if (cents < 0) {
    throw BankFileException(
      BankFileProblem.badAmount,
      line: position,
      detail: 'a signed camt amount',
    );
  }
  return sign == 'DBIT' ? -cents : cents;
}

int _signed(XmlElement bal, String? currency) {
  final amt = _at(bal, ['Amt']);
  final ccy = amt?.getAttribute('Ccy') ?? currency ?? '';
  final cents = bankAmount(amt?.innerText ?? '', bankCurrency(ccy));
  return _text(bal, ['CdtDbtInd']) == 'DBIT' ? -cents : cents;
}

DateTime? _day(XmlElement entry, String name, int position) {
  final e = _at(entry, [name]);
  if (e == null) return null;
  final text = _text(e, ['Dt']).isNotEmpty
      ? _text(e, ['Dt'])
      : _text(e, ['DtTm']);
  return bankIsoDay(text, line: position);
}

Iterable<XmlElement> _kids(XmlElement? e, String local) =>
    e == null ? const [] : e.childElements.where((c) => c.name.local == local);

XmlElement? _at(XmlElement? e, List<String> path) {
  var cur = e;
  for (final p in path) {
    cur = _kids(cur, p).firstOrNull;
    if (cur == null) return null;
  }
  return cur;
}

String _text(XmlElement? e, List<String> path) =>
    _at(e, path)?.innerText.trim() ?? '';

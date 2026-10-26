// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Open Financial Exchange, the statement North American banks (and
// Quicken's QFX) hand out: version 1.x in SGML, where a value's tag is
// often never closed, and 2.x in XML. Both are read by one tokenizer: a tag
// followed by text is a value, a tag followed by another tag opens an
// aggregate. A bank statement (STMTRS) or a card statement (CCSTMTRS)
// gives the account, its currency and one line per STMTTRN; `FITID` is
// the bank's identity of the movement. Pure Dart.
import 'bank_statement.dart';
import 'bank_values.dart';
import 'structured_reference.dart';

final _token = RegExp(r'<(/?)([A-Za-z0-9._]+)>([^<]*)');

/// The statement an OFX [text] carries.
BankStatement readOfx(String text) {
  final start = text.indexOf(RegExp('<OFX>', caseSensitive: false));
  if (start < 0) {
    throw const BankFileException(
      BankFileProblem.malformed,
      detail: 'no <OFX>',
    );
  }
  final root = _treeOf(text.substring(start));
  final statements = [...root.all('STMTRS'), ...root.all('CCSTMTRS')];
  if (statements.isEmpty) {
    throw const BankFileException(
      BankFileProblem.malformed,
      detail: 'no statement',
    );
  }
  String? account;
  String? currency;
  int? closing;
  final lines = <BankLine>[];
  for (final s in statements) {
    final from = s.child('BANKACCTFROM') ?? s.child('CCACCTFROM');
    final id = from?.value('ACCTID') ?? '';
    final bank = from?.value('BANKID') ?? '';
    final number = RegExp(r'^[A-Za-z]{2}\d{2}').hasMatch(id)
        ? compactIban(id)
        : bank.isEmpty || id.isEmpty
        ? id
        : '$bank/$id';
    if (account != null && number != account) {
      throw const BankFileException(
        BankFileProblem.malformed,
        detail: 'several accounts in one file',
      );
    }
    account = number;
    final ccy = bankCurrency(s.value('CURDEF') ?? '');
    currency ??= ccy;
    final list = s.child('BANKTRANLIST');
    for (final t in list?.all('STMTTRN') ?? const <_Node>[]) {
      lines.add(_lineOf(t, lines.length + 1, ccy));
    }
    final bal = s.child('LEDGERBAL')?.value('BALAMT');
    if (bal != null) closing = _ofxAmount(bal, ccy);
  }
  return BankStatement(
    format: BankFileFormat.ofx,
    account: account ?? '',
    currency: currency ?? '',
    closingCents: closing,
    lines: lines,
  );
}

BankLine _lineOf(_Node t, int position, String currency) {
  final posted = _day(t.value('DTPOSTED'), position);
  final user = t.value('DTUSER');
  final refnum = normalizeReference(t.value('REFNUM') ?? '');
  final memo = t.value('MEMO') ?? '';
  return BankLine(
    position: position,
    bookingDate: posted,
    valueDate: user == null || user.isEmpty ? posted : _day(user, position),
    amountCents: _ofxAmount(t.value('TRNAMT') ?? '', currency, line: position),
    currency: currency,
    transactionId: t.value('FITID') ?? '',
    counterpartyName: t.value('NAME') ?? t.child('PAYEE')?.value('NAME') ?? '',
    reference: isQrReference(refnum) || isCreditorReference(refnum)
        ? refnum
        : structuredReferenceIn(memo) ?? '',
    remittance: memo,
  );
}

DateTime _day(String? text, int position) {
  final m = RegExp(r'^(\d{4})(\d{2})(\d{2})').firstMatch(text ?? '');
  if (m == null) {
    throw BankFileException(
      BankFileProblem.badDate,
      line: position,
      detail: text ?? '',
    );
  }
  return bankDay(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
    line: position,
  );
}

class _Node {
  _Node(this.name);
  final String name;
  final Map<String, String> values = {};
  final List<_Node> children = [];

  String? value(String key) => values[key];
  _Node? child(String key) => children.where((c) => c.name == key).firstOrNull;

  /// Every aggregate named [key] below this one, in document order.
  Iterable<_Node> all(String key) sync* {
    for (final c in children) {
      if (c.name == key) yield c;
      yield* c.all(key);
    }
  }
}

_Node _treeOf(String text) {
  final root = _Node('');
  final stack = [root];
  final tokens = _token.allMatches(text).toList();
  for (final (i, m) in tokens.indexed) {
    final closing = m.group(1)!.isNotEmpty;
    final name = m.group(2)!.toUpperCase();
    final content = _unescape(m.group(3)!.trim());
    if (closing) {
      final at = stack.lastIndexWhere((n) => n.name == name);
      // A closed value tag (OFX 2.x) closes nothing that is open.
      if (at > 0) stack.removeRange(at, stack.length);
      continue;
    }
    if (content.isNotEmpty) {
      stack.last.values.putIfAbsent(name, () => content);
      continue;
    }
    final next = i + 1 < tokens.length ? tokens[i + 1] : null;
    final emptyValue =
        next != null &&
        next.group(1)!.isNotEmpty &&
        next.group(2)!.toUpperCase() == name;
    if (emptyValue) {
      stack.last.values.putIfAbsent(name, () => '');
      continue;
    }
    final node = _Node(name);
    stack.last.children.add(node);
    stack.add(node);
  }
  return root;
}

String _unescape(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

/// An OFX amount: a point or, in a file of a comma locale, a comma as its
/// radix (the specification allows either), never a grouping separator.
int _ofxAmount(String text, String currency, {int? line}) => bankAmount(
  text,
  currency,
  line: line,
  decimalSeparator: text.contains(',') && !text.contains('.') ? ',' : '.',
);

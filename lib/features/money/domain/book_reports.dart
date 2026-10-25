// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The books as an accountant reads them, from the same postings the FEC
// writes: the general ledger (grand-livre), the trial balance with its
// auxiliary balance (balance générale et auxiliaire) and the journals with
// their centralising summary (journaux, journal centralisateur). What the
// FEC says can be read in the app, line for line: the entry numbers, the
// accounts and the third parties are the FEC's own.
//
// Pure Dart: amounts are integer minor units in the book's currency; the
// caller formats money and dates and passes the words.
import 'book_ledger.dart';
import 'posting.dart';

export 'book_ledger.dart';

/// The words of the book reports, English by default; the app passes the
/// localized copy.
class BookReportWords {
  const BookReportWords({
    this.total = 'Total',
    this.grandTotal = 'Grand total',
    this.auxiliary = 'Auxiliary balance',
    this.summary = 'Summary of the journals',
    this.debitSide = 'Dr',
    this.creditSide = 'Cr',
    this.sales = 'Sales',
    this.bank = 'Bank',
    this.purchases = 'Purchases',
    this.other = 'Miscellaneous',
  });

  final String total;
  final String grandTotal;
  final String auxiliary;
  final String summary;
  final String debitSide;
  final String creditSide;
  final String sales;
  final String bank;
  final String purchases;
  final String other;

  String journal(PostingJournal j) => switch (j) {
    PostingJournal.sales => sales,
    PostingJournal.bank => bank,
    PostingJournal.purchases => purchases,
    PostingJournal.other => other,
  };
}

/// How the caller writes an amount (minor units of the book's currency)
/// and a day.
typedef BookFormat = ({
  String Function(int minor) money,
  String Function(DateTime day) date,
});

/// A report row: a heading, a total (strong) or a plain line.
enum _Kind { line, heading, total }

Map<String, Object?> _row({
  _Kind kind = _Kind.line,
  String label = '',
  String detail = '',
  String debit = '',
  String credit = '',
  String balance = '',
}) => {
  'heading': kind == _Kind.heading,
  'strong': kind == _Kind.total,
  'label': label,
  'detail': detail,
  'debit': debit,
  'credit': credit,
  'balance': balance,
};

String _side(int balance, BookFormat f, BookReportWords w) => balance == 0
    ? f.money(0)
    : '${f.money(balance.abs())} ${balance > 0 ? w.debitSide : w.creditSide}';

Map<String, Object?> _common(
  BookLedger books,
  BookFormat f,
  int debit,
  int credit,
  List<Map<String, Object?>> rows,
) => {
  'book_period': '${f.date(books.year.from)} – ${f.date(books.year.to)}',
  'book_rows': rows,
  'book_total_debit': f.money(debit),
  'book_total_credit': f.money(credit),
};

/// The general ledger's data: per account its lines and running balance,
/// then the account's total.
Map<String, Object?> _generalLedgerReportData(
  BookLedger books,
  BookFormat f, {
  BookReportWords words = const BookReportWords(),
}) {
  final rows = <Map<String, Object?>>[];
  var debit = 0;
  var credit = 0;
  for (final MapEntry(key: code, value: lines)
      in books.generalLedger().entries) {
    rows.add(_row(kind: _Kind.heading, label: '$code ${books.nameOf(code)}'));
    var d = 0;
    var c = 0;
    for (final l in lines) {
      d += l.debit;
      c += l.credit;
      rows.add(
        _row(
          label: '${f.date(l.date)} · ${l.entry}',
          detail: l.piece,
          debit: l.debit == 0 ? '' : f.money(l.debit),
          credit: l.credit == 0 ? '' : f.money(l.credit),
          balance: _side(l.balance, f, words),
        ),
      );
    }
    debit += d;
    credit += c;
    rows.add(
      _row(
        kind: _Kind.total,
        label: '${words.total} $code',
        debit: f.money(d),
        credit: f.money(c),
        balance: _side(d - c, f, words),
      ),
    );
  }
  return _common(books, f, debit, credit, rows);
}

/// The trial balance's data: every account's totals and balance, the grand
/// total, then the auxiliary balance per collective account.
Map<String, Object?> _trialBalanceReportData(
  BookLedger books,
  BookFormat f, {
  BookReportWords words = const BookReportWords(),
}) {
  final accounts = books.trialBalance();
  final debit = accounts.fold(0, (s, a) => s + a.debit);
  final credit = accounts.fold(0, (s, a) => s + a.credit);
  final rows = <Map<String, Object?>>[
    for (final a in accounts)
      _row(
        label: '${a.code} ${a.name}',
        debit: f.money(a.debit),
        credit: f.money(a.credit),
        balance: _side(a.balance, f, words),
      ),
    _row(
      kind: _Kind.total,
      label: words.grandTotal,
      debit: f.money(debit),
      credit: f.money(credit),
      balance: _side(debit - credit, f, words),
    ),
  ];
  final aux = books.auxiliaryBalance();
  if (aux.isNotEmpty) {
    rows.add(_row(kind: _Kind.heading, label: words.auxiliary));
  }
  for (final collective in {for (final a in aux) a.collective}) {
    final of = [
      for (final a in aux)
        if (a.collective == collective) a,
    ];
    for (final a in of) {
      rows.add(
        _row(
          label: '${a.aux} ${a.name}'.trim(),
          detail: collective,
          debit: f.money(a.debit),
          credit: f.money(a.credit),
          balance: _side(a.balance, f, words),
        ),
      );
    }
    final d = of.fold(0, (s, a) => s + a.debit);
    final c = of.fold(0, (s, a) => s + a.credit);
    rows.add(
      _row(
        kind: _Kind.total,
        label: '${words.total} $collective',
        debit: f.money(d),
        credit: f.money(c),
        balance: _side(d - c, f, words),
      ),
    );
  }
  return _common(books, f, debit, credit, rows);
}

/// The journals' data: each journal's entries and lines, its total, then
/// the centralising summary per journal and the grand total.
Map<String, Object?> _journalsReportData(
  BookLedger books,
  BookFormat f, {
  BookReportWords words = const BookReportWords(),
}) {
  final rows = <Map<String, Object?>>[];
  final totals = books.journalTotals();
  for (final t in totals) {
    rows.add(
      _row(
        kind: _Kind.heading,
        label: '${t.journal.code} ${words.journal(t.journal)}',
      ),
    );
    for (final e in books.entriesOf(t.journal)) {
      rows.add(
        _row(
          kind: _Kind.total,
          label: '${e.entry} · ${f.date(e.posting.date)}',
          detail: BookLedger.pieceOf(e.posting),
        ),
      );
      for (final l in e.lines) {
        rows.add(
          _row(
            label: '${l.accountCode} ${books.nameOf(l.accountCode)}',
            debit: l.debit.minor == 0 ? '' : f.money(l.debit.minor),
            credit: l.credit.minor == 0 ? '' : f.money(l.credit.minor),
          ),
        );
      }
    }
    rows.add(
      _row(
        kind: _Kind.total,
        label: '${words.total} ${t.journal.code}',
        debit: f.money(t.debit),
        credit: f.money(t.credit),
      ),
    );
  }
  rows.add(_row(kind: _Kind.heading, label: words.summary));
  for (final t in totals) {
    rows.add(
      _row(
        label: '${t.journal.code} ${words.journal(t.journal)}',
        detail: '${t.entries}',
        debit: f.money(t.debit),
        credit: f.money(t.credit),
      ),
    );
  }
  final debit = totals.fold(0, (s, t) => s + t.debit);
  final credit = totals.fold(0, (s, t) => s + t.credit);
  rows.add(
    _row(
      kind: _Kind.total,
      label: words.grandTotal,
      debit: f.money(debit),
      credit: f.money(credit),
    ),
  );
  return _common(books, f, debit, credit, rows);
}

/// The report data of [kindId] (`general_ledger`, `trial_balance`,
/// `journals`); null for any other kind.
Map<String, Object?>? bookReportData(
  String kindId,
  BookLedger books,
  BookFormat f, {
  BookReportWords words = const BookReportWords(),
}) => switch (kindId) {
  'general_ledger' => _generalLedgerReportData(books, f, words: words),
  'trial_balance' => _trialBalanceReportData(books, f, words: words),
  'journals' => _journalsReportData(books, f, words: words),
  _ => null,
};

/// The report kinds of the books.
const List<String> bookReportKinds = [
  'general_ledger',
  'trial_balance',
  'journals',
];

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2376 — the postings of one fiscal year of one book, totalled the way
// the book reports read them: per account, per third party, per account
// line with its running balance, per journal. The entry numbers, the
// accounts and the auxiliary accounts are the FEC's own (fec_postings.dart).
import 'accounting_format.dart';
import 'book_chart.dart';
import 'fec_postings.dart';
import 'fiscal_year.dart';
import 'posting.dart';

/// One account's totals over the period.
class BookAccountTotal {
  const BookAccountTotal(this.code, this.name, this.debit, this.credit);
  final String code;
  final String name;
  final int debit;
  final int credit;

  /// Debit minus credit.
  int get balance => debit - credit;
}

/// One third party's totals on a collective account.
class BookAuxTotal {
  const BookAuxTotal({
    required this.collective,
    required this.aux,
    required this.name,
    required this.debit,
    required this.credit,
  });
  final String collective;

  /// The auxiliary account as the FEC writes it; empty when the party has
  /// no usable number.
  final String aux;
  final String name;
  final int debit;
  final int credit;
  int get balance => debit - credit;
}

/// One line of an account in the general ledger.
class BookLedgerLine {
  const BookLedgerLine({
    required this.date,
    required this.journal,
    required this.entry,
    required this.piece,
    required this.debit,
    required this.credit,
    required this.balance,
  });
  final DateTime date;
  final PostingJournal journal;
  final String entry;
  final String piece;
  final int debit;
  final int credit;

  /// The account's running balance after this line, debit minus credit.
  final int balance;
}

/// One journal's totals.
class BookJournalTotal {
  const BookJournalTotal(this.journal, this.entries, this.debit, this.credit);
  final PostingJournal journal;
  final int entries;
  final int debit;
  final int credit;
}

/// One line of a posting, in the book's currency, with its entry number.
typedef _Line = ({Posting posting, String entry, PostingLine line});

/// The postings of one fiscal year of one book, as the reports read them.
class BookLedger {
  BookLedger({
    required List<Posting> postings,
    required this.year,
    this.accountNames = const {},
    this.parties = const {},
    this.functionalCurrency,
  }) {
    final seen = <String, int>{};
    for (final p in postings) {
      final lines = inBookCurrency(p, functionalCurrency, null);
      if (lines == null) {
        unconverted.add(pieceOf(p));
        continue;
      }
      final base = '${p.journal.code}-${pieceOf(p)}';
      final n = seen[base] = (seen[base] ?? 0) + 1;
      final entry = n == 1 ? base : '$base-$n';
      for (final (line, _) in lines) {
        _lines.add((posting: p, entry: entry, line: line));
      }
    }
  }

  final FiscalYear year;
  final Map<String, String> accountNames;
  final Map<String, PostingParty> parties;
  final String? functionalCurrency;

  /// The documents left out: in another currency than the book's, with
  /// no recorded rate. A report with any is not printed.
  final List<String> unconverted = [];
  final List<_Line> _lines = [];

  /// The piece a posting books: its document number, or the document's
  /// short id when it has none (the FEC's PieceRef).
  static String pieceOf(Posting p) => p.documentNumber.isNotEmpty
      ? p.documentNumber
      : p.documentId.substring(0, p.documentId.length.clamp(0, 8));

  String nameOf(String code) => accountNames[code] ?? code;

  /// Every account with a line, by code.
  List<BookAccountTotal> trialBalance() {
    final debit = <String, int>{};
    final credit = <String, int>{};
    for (final (posting: _, entry: _, :line) in _lines) {
      debit[line.accountCode] =
          (debit[line.accountCode] ?? 0) + line.debit.minor;
      credit[line.accountCode] =
          (credit[line.accountCode] ?? 0) + line.credit.minor;
    }
    return [
      for (final code in debit.keys.toList()..sort())
        BookAccountTotal(code, nameOf(code), debit[code]!, credit[code]!),
    ];
  }

  /// Every third party on a customers or suppliers account, by collective
  /// then auxiliary account.
  List<BookAuxTotal> auxiliaryBalance() {
    final rule = accountingTargets
        .firstWhere((t) => t.id == 'fec')
        .customerIdRule;
    final totals = <(String, String, String), (int, int)>{};
    for (final (:posting, entry: _, :line) in _lines) {
      if (line.role != BookRole.customers && line.role != BookRole.suppliers) {
        continue;
      }
      final party = parties[posting.documentId];
      final aux = party == null
          ? ''
          : fecAuxAccount(line.accountCode, party.number, rule) ?? '';
      final key = (line.accountCode, aux, party?.name ?? '');
      final (d, c) = totals[key] ?? (0, 0);
      totals[key] = (d + line.debit.minor, c + line.credit.minor);
    }
    final keys = totals.keys.toList()
      ..sort((a, b) {
        final byCollective = a.$1.compareTo(b.$1);
        if (byCollective != 0) return byCollective;
        final byAux = a.$2.compareTo(b.$2);
        return byAux != 0 ? byAux : a.$3.compareTo(b.$3);
      });
    return [
      for (final k in keys)
        BookAuxTotal(
          collective: k.$1,
          aux: k.$2,
          name: k.$3,
          debit: totals[k]!.$1,
          credit: totals[k]!.$2,
        ),
    ];
  }

  /// Each account's lines in posting order, with the running balance.
  Map<String, List<BookLedgerLine>> generalLedger() {
    final byAccount = <String, List<BookLedgerLine>>{};
    for (final (:posting, :entry, :line) in _lines) {
      final lines = byAccount.putIfAbsent(line.accountCode, () => []);
      final before = lines.isEmpty ? 0 : lines.last.balance;
      lines.add(
        BookLedgerLine(
          date: posting.date,
          journal: posting.journal,
          entry: entry,
          piece: pieceOf(posting),
          debit: line.debit.minor,
          credit: line.credit.minor,
          balance: before + line.debit.minor - line.credit.minor,
        ),
      );
    }
    return {
      for (final code in byAccount.keys.toList()..sort())
        code: byAccount[code]!,
    };
  }

  /// Each journal that has an entry, in journal order.
  List<BookJournalTotal> journalTotals() => [
    for (final j in PostingJournal.values)
      if (_lines.any((l) => l.posting.journal == j))
        BookJournalTotal(
          j,
          {
            for (final l in _lines)
              if (l.posting.journal == j) l.entry,
          }.length,
          _sum(j, (l) => l.debit.minor),
          _sum(j, (l) => l.credit.minor),
        ),
  ];

  int _sum(PostingJournal j, int Function(PostingLine l) amount) => _lines
      .where((l) => l.posting.journal == j)
      .fold(0, (s, l) => s + amount(l.line));

  /// The entries of [journal], each with its lines, in posting order.
  List<({String entry, Posting posting, List<PostingLine> lines})> entriesOf(
    PostingJournal journal,
  ) {
    final entries =
        <String, ({String entry, Posting posting, List<PostingLine> lines})>{};
    for (final l in _lines) {
      if (l.posting.journal != journal) continue;
      entries
          .putIfAbsent(
            l.entry,
            () => (entry: l.entry, posting: l.posting, lines: <PostingLine>[]),
          )
          .lines
          .add(l.line);
    }
    return entries.values.toList();
  }
}

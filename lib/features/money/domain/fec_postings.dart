// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 — the FEC of an issuer that keeps a local book: the posting engine's
// entries (`compute_postings`), one row per line, on the book's own chart.
// Nothing is derived around the engine: the journals, the accounts, the
// pending tax and the purchases are what the engine booked.
//
//   * JournalCode is the posting's journal (VE, BQ, HA, OD).
//   * EcritureNum comes from the DOCUMENT it books (#927), never from a
//     per-file counter: `<journal>-<document>`, and `-2`, `-3`... for a
//     second entry of the same document in the same journal. Inside one
//     fiscal year a number names one entry; every line of the entry
//     carries it.
//   * A receivable or payable line (customers, suppliers) is lettered with
//     its document when that document's lines on the account balance in the
//     file; DateLet is then the date of the last of them
//     ([withLetteringDates]). An open balance stays unlettered.
//   * A receivable or payable line keeps the collective account in
//     CompteNum and names its third party in the auxiliary columns: the
//     collective's root followed by the member's or supplier's number
//     (`411M0001`, `4014`), as the French importers expect. A line whose
//     party has no usable number stops the file and is named: a FEC
//     without its auxiliary accounts is refused on import.
//   * An entry in another currency than the book's is written in the
//     book's currency at the document's recorded rate, the original amount
//     in Montantdevise / Idevise. Without a recorded rate the file is not
//     written.
import '../../../core/money/money_text.dart';
import '../../../core/time/date_text.dart';
import 'accounting_amount.dart';
import 'accounting_target.dart';
import 'book_chart.dart';
import 'fec.dart';
import 'fec_lettering.dart';
import 'posting.dart';

const _journalLabels = {
  PostingJournal.sales: 'Ventes',
  PostingJournal.bank: 'Banque',
  PostingJournal.purchases: 'Achats',
  PostingJournal.other: 'Opérations diverses',
};

// The FEC is a French file: its labels are French, as the arrêté reads them.
const _kindLabels = {
  PostingKind.invoice: 'Facture',
  PostingKind.creditNote: 'Avoir',
  PostingKind.receipt: 'Encaissement',
  PostingKind.refund: 'Remboursement',
  PostingKind.writeOff: 'Créance irrécouvrable',
  PostingKind.expense: 'Dépense',
  PostingKind.supplierBill: 'Facture fournisseur',
  PostingKind.supplierCreditNote: 'Avoir fournisseur',
  PostingKind.supplierPayment: 'Règlement fournisseur',
  PostingKind.vatRelease: 'TVA exigible',
  PostingKind.memberReceipt: 'Note de frais',
  PostingKind.reimbursement: 'Remboursement de frais',
};

const _lettered = {BookRole.customers, BookRole.suppliers};

/// The plan comptable names its collective accounts by their first three
/// digits (411 customers, 401 suppliers): the auxiliary account of a third
/// party starts with them.
const _collectiveRootLength = 3;

/// Why a posted FEC was not written.
enum FecBlock {
  /// A receivable or payable line's party has no number that makes a
  /// valid auxiliary account, or two parties would share one.
  partyCode,

  /// An entry in a foreign currency has no recorded exchange rate.
  missingRate,
}

class FecBlocker {
  const FecBlocker(this.block, this.subject);
  final FecBlock block;

  /// The party (`name (number)`) or the document (`number (currency)`).
  final String subject;

  @override
  bool operator ==(Object other) =>
      other is FecBlocker && other.block == block && other.subject == subject;

  @override
  int get hashCode => Object.hash(block, subject);

  @override
  String toString() => 'FecBlocker(${block.name}: $subject)';
}

/// A posted FEC: the file, or every blocker that stopped it (the file is
/// then empty: nothing is written around a blocker).
typedef PostedFecResult = ({String file, List<FecBlocker> blockers});

/// The auxiliary account of a party numbered [number] under the
/// collective account [collective]: the collective's root and the number
/// in capitals without separators, when [rule] admits it; null otherwise.
String? fecAuxAccount(String collective, String number, CustomerIdRule rule) {
  final code = number.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
  if (code.isEmpty) return null;
  if (rule.maxLength case final max? when code.length > max) return null;
  if (rule.charset case final charset?
      when !RegExp('^(?:$charset)\$').hasMatch(code)) {
    return null;
  }
  final root = collective.length < _collectiveRootLength
      ? collective
      : collective.substring(0, _collectiveRootLength);
  return '$root$code';
}

/// The FEC file of [postings] (in the engine's order), the accounts named
/// by [accountNames] (code → name; the code where the chart has none).
///
/// [parties] names the third party of each document; [partyRule] is what a
/// party's number may look like (the FEC target's customer id rule). An
/// entry whose currency is not [functionalCurrency] is converted at its
/// document's rate in [rates]. Every party and document that stops the
/// file is named in the result's blockers.
PostedFecResult buildFecFromPostings(
  List<Posting> postings, {
  required Map<String, String> accountNames,
  Map<String, PostingParty> parties = const {},
  CustomerIdRule partyRule = const CustomerIdRule(),
  String? functionalCurrency,
  Map<String, FxRate> rates = const {},
}) {
  final file = _PostedFec(
    accountNames: accountNames,
    parties: parties,
    partyRule: partyRule,
  );
  final rows = file.rows(postings, functionalCurrency, rates);
  if (file.blockers.isNotEmpty) {
    return (file: '', blockers: file.blockers.toList());
  }
  return (file: fecText(withLetteringDates(rows)), blockers: const []);
}

class _PostedFec {
  _PostedFec({
    required this.accountNames,
    required this.parties,
    required this.partyRule,
  });

  final Map<String, String> accountNames;
  final Map<String, PostingParty> parties;
  final CustomerIdRule partyRule;
  final blockers = <FecBlocker>{};
  final _auxOwners = <String, String>{};

  static String _clean(String text) =>
      text.replaceAll(RegExp(r'[\t\r\n]+'), ' ').trim();

  static String _amount(AccountingAmount a) =>
      minorToText(a.minor, a.currency, decimalSeparator: ',');

  static String _reference(Posting p) => p.documentNumber.isNotEmpty
      ? p.documentNumber
      : p.documentId.substring(0, p.documentId.length.clamp(0, 8));

  /// The balance of each document's lines on each lettered account.
  static Map<String, int> _openBalances(List<Posting> postings) {
    final open = <String, int>{};
    for (final p in postings) {
      for (final l in p.lines) {
        if (!_lettered.contains(l.role)) continue;
        final key = '${l.accountCode}|${_reference(p)}';
        open[key] = (open[key] ?? 0) + l.debit.minor - l.credit.minor;
      }
    }
    return open;
  }

  /// The auxiliary account of [p]'s party under [l]'s collective; a
  /// party without one, or sharing one with another party, is a blocker.
  String _auxOf(Posting p, PostingLine l) {
    final party = parties[p.documentId];
    final aux = party == null
        ? null
        : fecAuxAccount(l.accountCode, party.number, partyRule);
    final owner = '${party?.kind}:${party?.number}';
    if (aux == null || (_auxOwners[aux] ??= owner) != owner) {
      blockers.add(
        FecBlocker(
          FecBlock.partyCode,
          party == null ? _reference(p) : '${party.name} (${party.number})',
        ),
      );
      return '';
    }
    return aux;
  }

  List<List<String>> rows(
    List<Posting> postings,
    String? functional,
    Map<String, FxRate> rates,
  ) {
    final open = _openBalances(postings);
    final seen = <String, int>{};
    final rows = <List<String>>[];
    for (final p in postings) {
      final lines = inBookCurrency(p, functional, rates[p.documentId]);
      if (lines == null) {
        blockers.add(
          FecBlocker(
            FecBlock.missingRate,
            '${_reference(p)} (${p.lines.first.debit.currency})',
          ),
        );
        continue;
      }
      final ref = _reference(p);
      final base = '${p.journal.code}-$ref';
      final n = seen[base] = (seen[base] ?? 0) + 1;
      final number = n == 1 ? base : '$base-$n';
      for (final (line, original) in lines) {
        rows.add(_row(p, number, line, original, open));
      }
    }
    return rows;
  }

  List<String> _row(
    Posting p,
    String number,
    PostingLine l,
    AccountingAmount? original,
    Map<String, int> open,
  ) {
    final ref = _reference(p);
    final third = _lettered.contains(l.role);
    final letter = third && open['${l.accountCode}|$ref'] == 0;
    return [
      p.journal.code,
      _journalLabels[p.journal]!,
      number,
      ymd(p.date),
      l.accountCode,
      _clean(accountNames[l.accountCode] ?? l.accountCode),
      if (third) _auxOf(p, l) else '',
      _clean(third ? parties[p.documentId]?.name ?? '' : ''),
      _clean(ref),
      ymd(p.date),
      _clean('${_kindLabels[p.kind] ?? p.kind.wire} $ref'),
      _amount(l.debit),
      _amount(l.credit),
      if (letter) ref else '',
      // DateLet: filled from the lettering group.
      '',
      ymd(p.date),
      if (original == null) '' else _amount(original),
      original?.currency ?? '',
    ];
  }
}

/// The lines of [p] in [functional] currency, each with its original
/// amount when it was converted (null when the entry is already in the
/// book's currency); null when it needs a [rate] and has none. The entry
/// stays balanced: the cents left by converting line by line go to the
/// largest line of the side that is short.
List<(PostingLine, AccountingAmount?)>? inBookCurrency(
  Posting p,
  String? functional,
  FxRate? rate,
) {
  final currency = p.lines.isEmpty ? null : p.lines.first.debit.currency;
  if (functional == null || currency == null || currency == functional) {
    return [for (final l in p.lines) (l, null)];
  }
  if (rate == null ||
      rate.base.toUpperCase() != currency ||
      rate.quote.toUpperCase() != functional) {
    return null;
  }
  final converted = [
    for (final l in p.lines)
      _line(
        l,
        convert(l.debit, rate, RoundingPolicy.halfUp),
        convert(l.credit, rate, RoundingPolicy.halfUp),
      ),
  ];
  _balance(converted, functional);
  return [
    for (var i = 0; i < p.lines.length; i++)
      (
        converted[i],
        p.lines[i].debit.minor != 0 ? p.lines[i].debit : p.lines[i].credit,
      ),
  ];
}

PostingLine _line(PostingLine l, AccountingAmount debit, AccountingAmount credit) =>
    PostingLine(
      role: l.role,
      qualifier: l.qualifier,
      accountCode: l.accountCode,
      debit: debit,
      credit: credit,
    );

/// Gives the rounding gap of [lines] to the largest line of the short side.
void _balance(List<PostingLine> lines, String currency) {
  var gap = 0;
  for (final l in lines) {
    gap += l.debit.minor - l.credit.minor;
  }
  if (gap == 0) return;
  // Debits ahead: the largest credit takes the cents; credits ahead: the
  // largest debit does.
  final toCredit = gap > 0;
  int side(PostingLine l) => toCredit ? l.credit.minor : l.debit.minor;
  var best = -1;
  for (var i = 0; i < lines.length; i++) {
    if (side(lines[i]) == 0) continue;
    if (best < 0 || side(lines[i]) > side(lines[best])) best = i;
  }
  final l = lines[best];
  final cents = AccountingAmount(currency, gap.abs());
  lines[best] = toCredit
      ? _line(l, l.debit, l.credit + cents)
      : _line(l, l.debit + cents, l.credit);
}

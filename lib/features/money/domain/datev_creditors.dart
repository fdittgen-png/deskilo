// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Kreditoren of a DATEV export: one Personenkonto per supplier, numbered
// from the supplier number the space already gives (`suppliers.supplier_number`)
// above the accountant's first Kreditor, never invented. The rows are the
// posting engine's purchases entries (supplier bills, credit notes and their
// payments), not a second derivation: every line of an entry other than the
// supplier's payable is booked against the supplier's Kreditor in place of
// the collective payable, on the engine's own accounts and per-rate tax
// accounts. DATEV keeps open items per Kreditor.
import 'package:meta/meta.dart';

import 'book_chart.dart';
import 'datev.dart';
import 'datev_fields.dart';
import 'datev_problem.dart';
import 'euro_format.dart';
import 'invoice.dart';
import 'posting.dart';

/// The Kreditor of the supplier number [number]: [base] plus its counter,
/// as long as the number is a counter and the sum falls in DATEV's Kreditor
/// range for Sachkonten of [accountLength] digits; null otherwise.
@visibleForTesting
String? datevCreditorOf(
  String number, {
  required int base,
  required int accountLength,
}) {
  if (!_counter.hasMatch(number)) return null;
  final (first, last) = DatevFormatRules.creditorRange(accountLength);
  final account = base + int.parse(number);
  return account < first || account > last ? null : '$account';
}

/// A supplier number is the counter itself: digits, not more than fit.
final _counter = RegExp(r'^\d{1,15}$');

/// What the books hold of the purchases side for one export: the postings
/// the engine made (any kind; only the supplier events are used), the
/// supplier of each document, the accountant's first Kreditor and what
/// stopped the engine.
class DatevPurchases {
  const DatevPurchases({
    required this.creditorBase,
    this.postings = const [],
    this.parties = const {},
    this.blocked = const [],
  });

  /// The Kreditor of supplier counter 0: the accountant's first free one.
  final int creditorBase;
  final List<Posting> postings;

  /// The supplier of each document, by document id (`posting_parties`).
  final Map<String, PostingParty> parties;

  /// The roles without an account and the documents without a rate that
  /// kept the engine from posting; the export is then not written.
  final List<String> blocked;
}

const _texts = {
  PostingKind.supplierBill: 'Eingangsrechnung',
  PostingKind.supplierCreditNote: 'Lieferantengutschrift',
  PostingKind.supplierPayment: 'Zahlung Lieferant',
};

/// The Kreditor of every supplier an export books, the rows against it, the
/// party each is written to the Stammdaten as, and what stopped a supplier
/// from having one.
class DatevCreditors {
  const DatevCreditors._(this.bookings, this.parties, this.problems);

  factory DatevCreditors.of(
    DatevPurchases purchases, {
    required int accountLength,
  }) {
    final problems = <DatevProblem>[];
    final bookings = <DatevBooking>[];
    final parties = <String, InvoiceParty>{};
    final byAccount = <String, Map<String, String>>{};
    final named = <(String, String)>{};
    final currencies = <String>{};
    for (final p in purchases.postings) {
      if (!_texts.containsKey(p.kind)) continue;
      currencies.addAll([
        for (final l in p.lines) l.debit.currency.toUpperCase(),
      ]);
      final ref = _reference(p);
      final party = purchases.parties[p.documentId];
      final number = party?.number ?? '';
      final name = party == null || party.name.isEmpty ? ref : party.name;
      final account = datevCreditorOf(
        number,
        base: purchases.creditorBase,
        accountLength: accountLength,
      );
      if (account == null) {
        if (named.add((name, number))) {
          problems.add(DatevSupplierNumber(name, number));
        }
        continue;
      }
      (byAccount[account] ??= {})[number] = name;
      parties[account] = InvoiceParty(name: name, memberNumber: number);
      bookings.addAll(_bookingsOf(p, account, ref));
    }
    for (final MapEntry(key: account, value: suppliers) in byAccount.entries) {
      if (suppliers.length > 1) {
        problems.add(DatevCreditorClash(account, suppliers.values.toList()));
      }
    }
    problems.addAll([
      for (final c in currencies.toList()..sort())
        if (!isEuroFormatCurrency(c)) DatevCurrency(c),
    ]);
    return DatevCreditors._(
      problems.isEmpty ? bookings : const [],
      parties,
      problems,
    );
  }

  /// The supplier side as rows, in the engine's order.
  final List<DatevBooking> bookings;

  /// The party each Kreditor is written to the Stammdaten as, by account.
  final Map<String, InvoiceParty> parties;
  final List<DatevProblem> problems;
}

String _reference(Posting p) => p.documentNumber.isNotEmpty
    ? p.documentNumber
    : p.documentId.substring(0, p.documentId.length.clamp(0, 8));

/// The lines of [p] other than the payable, each against [creditor] on its
/// own side; a payment goes in the bank Stapel, a bill or credit note in the
/// purchases one.
List<DatevBooking> _bookingsOf(Posting p, String creditor, String ref) => [
  for (final l in p.lines)
    if (l.role != BookRole.suppliers && l.debit.minor != l.credit.minor)
      DatevBooking(
        cents: (l.debit.minor - l.credit.minor).abs(),
        debit: l.debit.minor > l.credit.minor ? l.accountCode : creditor,
        credit: l.debit.minor > l.credit.minor ? creditor : l.accountCode,
        date: p.date,
        documentRef: ref,
        text: '${_texts[p.kind]} $ref',
        journal: p.kind == PostingKind.supplierPayment
            ? DatevJournal.bank
            : DatevJournal.purchases,
      ),
];

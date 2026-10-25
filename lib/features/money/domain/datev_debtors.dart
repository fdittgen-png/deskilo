// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Personenkonten of a DATEV export: one Debitor per member, numbered
// from the counter of the member number the space already gives (the number
// sequence `member`) above the accountant's first Debitor, never invented. DATEV keeps open items per Debitor; one
// collective account would leave the accountant to split every customer
// by hand.
import 'package:meta/meta.dart';

import 'datev_problem.dart';
import 'invoice.dart';
import 'ledger_entry.dart';
import 'number_sequence.dart';

/// The Debitor of the member number [number]: [base] plus the counter the
/// member series [sequence] wrote into it (`M-2026-0007` is counter 7), as
/// long as it falls in DATEV's Debitor range for Sachkonten of
/// [accountLength] digits; null otherwise.
@visibleForTesting
String? datevDebtorOf(
  String number, {
  required NumberSequence sequence,
  required int base,
  required int accountLength,
}) {
  final counter = sequence.counterOf(number);
  if (counter == null) return null;
  final (first, last) = DatevFormatRules.debtorRange(accountLength);
  final account = base + counter;
  return account < first || account > last ? null : '$account';
}

/// The Debitor of every member an export books, the party each one is
/// written to the Stammdaten as, and what stopped a member from having one.
class DatevDebtors {
  const DatevDebtors._(this.accounts, this.parties, this.problems);

  /// The members of [invoices] and of the expense credits of [ledger], each
  /// with the member number frozen on their latest invoice, else the one
  /// [memberNumbers] holds today (a document issued before numbers were
  /// frozen carries none). [memberNames] names a member who has no
  /// invoice in the export.
  factory DatevDebtors.of({
    required List<Invoice> invoices,
    required List<LedgerEntry> ledger,
    required int accountLength,
    required NumberSequence sequence,
    required int base,
    Map<String, String> memberNumbers = const {},
    Map<String, String> memberNames = const {},
  }) {
    final latest = <String, Invoice>{};
    for (final i in invoices) {
      final seen = latest[i.memberId];
      if (seen == null || !i.issuedAt.isBefore(seen.issuedAt)) {
        latest[i.memberId] = i;
      }
    }
    final members = <String>{
      ...latest.keys,
      for (final e in ledger)
        if (e.kind == LedgerKind.credit && e.category == LedgerCategory.expense)
          e.memberId,
    };
    final accounts = <String, String>{};
    final parties = <String, InvoiceParty>{};
    final problems = <DatevProblem>[];
    final byAccount = <String, List<String>>{};
    for (final member in [...members]..sort()) {
      final invoice = latest[member];
      final frozen = invoice?.buyerParty?.memberNumber ?? '';
      final number = frozen.isNotEmpty ? frozen : memberNumbers[member] ?? '';
      final name = invoice?.clientName ?? memberNames[member] ?? member;
      final account = datevDebtorOf(
        number,
        sequence: sequence,
        base: base,
        accountLength: accountLength,
      );
      if (account == null) {
        problems.add(DatevMemberNumber(name, number));
        continue;
      }
      accounts[member] = account;
      parties[member] = (invoice?.buyerParty ?? const InvoiceParty()).copyWith(
        name: name,
        memberNumber: number,
      );
      (byAccount[account] ??= []).add(name);
    }
    for (final MapEntry(key: account, value: names) in byAccount.entries) {
      if (names.length > 1) problems.add(DatevDebtorClash(account, names));
    }
    return DatevDebtors._(accounts, parties, problems);
  }

  /// The Debitor of each member, by member id.
  final Map<String, String> accounts;

  /// The party each Debitor is written to the Stammdaten as, by member id.
  final Map<String, InvoiceParty> parties;
  final List<DatevProblem> problems;
}

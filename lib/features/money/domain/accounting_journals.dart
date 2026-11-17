// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3470 -- the business's accounting journals: the one accessor every
// accounting export reads them through, and the rules a value must meet to
// be kept (the same rules the server holds: set_accounting_journals, 0773).
// A value is whole or refused whole; an invalid code is never cleaned into
// another journal.
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart' show AccountingJournal;
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show PostingJournal;
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';

import '../../../core/jurisdiction/installed_accounting_formats.dart';

/// The journals the business's exports write: the stored ones when the
/// business set them, else the country add-on's defaults.
FecJournals accountingJournalsOf(Map<String, Object?> stored) =>
    FecJournals.fromJson(stored) ?? _installedFecJournals();

/// The code the business's [journals] give a posting journal, for the
/// writers that take a function; null [journals]: the engine's own codes.
String Function(PostingJournal)? journalCodeOf(FecJournals? journals) =>
    journals == null ? null : (j) => journalFor(journals, j).code;

/// What is wrong with a journal of a value.
enum JournalProblem {
  /// The code is empty.
  code,

  /// The label is empty.
  label,

  /// A line break, a tab, another control character or a pipe: the FEC
  /// separates its fields with them.
  character,

  /// The code is another journal's.
  duplicate,
}

final _forbidden = RegExp(r'[\x00-\x1f\x7f|]');

/// Whether [text] may stand in a journal's code or label: no control
/// character and no pipe.
bool journalTextAllowed(String text) => !_forbidden.hasMatch(text);

/// The first problem of [journals], in the server's order (sales, bank,
/// purchases, misc; code, label, character, duplicate), or null when the
/// value can be kept.
({String role, JournalProblem problem})? journalsProblem(FecJournals journals) {
  final codes = <String>{};
  for (final (role, j) in journals.byRole) {
    if (j.code.trim().isEmpty) {
      return (role: role, problem: JournalProblem.code);
    }
    if (j.label.trim().isEmpty) {
      return (role: role, problem: JournalProblem.label);
    }
    if (_forbidden.hasMatch(j.code) || _forbidden.hasMatch(j.label)) {
      return (role: role, problem: JournalProblem.character);
    }
    if (!codes.add(j.code)) {
      return (role: role, problem: JournalProblem.duplicate);
    }
  }
  return null;
}

/// The journals of the installed FEC declaration.
FecJournals _installedFecJournals() {
  final declared = accountingFormatOf('fec').journals;
  FecJournal of(String role) => switch (declared[role]) {
    final AccountingJournal j => FecJournal(code: j.code, label: j.label),
    null => throw StateError('the FEC declaration has no $role journal'),
  };
  return FecJournals(
    sales: of('sales'),
    bank: of('bank'),
    purchases: of('purchases'),
    misc: of('misc'),
  );
}


/// The FEC chart declared by this build, read from the captured reference.
/// The same defaults are offered when SAF-T asks for a derived account map.
FecAccounts fecAccountsOf({
  required TaxReferenceSet reference,
  required FecJournals journals,
  String? vat,
}) => FecAccounts(reference: reference, journals: journals, vat: vat,
  chartCountry: accountingFormatOf('fec').chartCountry);

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3470 -- the business's accounting journals: the one accessor every
// accounting export reads them through, and the rules a value must meet to
// be kept (the same rules the server holds: set_accounting_journals, 0773).
// A value is whole or refused whole; an invalid code is never cleaned into
// another journal.
import 'fec_accounts.dart';

/// The journals the business's exports write: the stored ones when the
/// business set them, else the country add-on's defaults.
FecJournals accountingJournalsOf(Map<String, Object?> stored) =>
    FecJournals.fromJson(stored) ?? FecJournals.installed();

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

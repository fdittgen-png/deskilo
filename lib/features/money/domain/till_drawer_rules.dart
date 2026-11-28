// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4367 -- what the drawer's forms check before anything is sent: the shape of what was typed. The server decides the
// rest (a reason not on the list, a limit, a difference that needs its reason); its refusal is said in words as it comes.
import 'till_drawer.dart';

/// The field a problem belongs to.
/// The longest name a till takes: the server's own check (`counter_tills`, 0907).
const int kTillNameMaxLength = 60;

enum DrawerField { name, amount, reason, banked, differenceReason }

/// What is wrong with a typed value.
enum DrawerProblem {
  nameMissing,
  amountInvalid,
  amountZero,
  reasonMissing,
  bankedAboveCounted,
  differenceReasonMissing,
  denominationsIncomplete,
}

/// A row of a count by denomination as it was typed: the value of one note or coin and how many; null is not a number.
typedef DenominationRow = ({int? value, int? count});

/// The count the rows describe: null when a row is half typed, a value of zero or below, or the same value twice.
/// Rows left empty (neither typed) are skipped.
Denominations? denominationsOfRows(List<DenominationRow> rows) {
  final counts = <int, int>{};
  for (final r in rows) {
    if (r.value == null && r.count == null) continue;
    final v = r.value;
    final c = r.count;
    if (v == null || c == null || v <= 0 || c < 0 || counts.containsKey(v)) return null;
    counts[v] = c;
  }
  return Denominations(counts);
}

Map<DrawerField, DrawerProblem> checkTillName(String name) => name.trim().isEmpty ? {DrawerField.name: DrawerProblem.nameMissing} : const {};

/// The float of a session: an amount (zero is a float), or the counted rows when the business counts by denomination.
Map<DrawerField, DrawerProblem> checkFloat({required int? amountMinor, required bool byDenomination, required Denominations? denominations}) {
  if (byDenomination && denominations == null) return {DrawerField.amount: DrawerProblem.denominationsIncomplete};
  if (amountMinor == null || amountMinor < 0) return {DrawerField.amount: DrawerProblem.amountInvalid};
  return const {};
}

/// A cash entry: an amount above zero and a reason chosen from the list.
Map<DrawerField, DrawerProblem> checkCashEntry({required int? amountMinor, required String? reason}) => {
  if (amountMinor == null) DrawerField.amount: DrawerProblem.amountInvalid else if (amountMinor <= 0) DrawerField.amount: DrawerProblem.amountZero,
  if (reason == null || reason.trim().isEmpty) DrawerField.reason: DrawerProblem.reasonMissing,
};

/// The count at the close. [expectedMinor] is known only to someone who may see it; without it the difference is the
/// server's to find and a reason is asked for when it says so.
Map<DrawerField, DrawerProblem> checkClose({
  required int? countedMinor,
  required int? bankedMinor,
  required bool byDenomination,
  required Denominations? denominations,
  required int? expectedMinor,
  required String differenceReason,
}) {
  if (byDenomination && denominations == null) return {DrawerField.amount: DrawerProblem.denominationsIncomplete};
  if (countedMinor == null || countedMinor < 0) return {DrawerField.amount: DrawerProblem.amountInvalid};
  return {
    if (bankedMinor != null && (bankedMinor < 0 || bankedMinor > countedMinor)) DrawerField.banked: DrawerProblem.bankedAboveCounted,
    if (expectedMinor != null && expectedMinor != countedMinor && differenceReason.trim().isEmpty) DrawerField.differenceReason: DrawerProblem.differenceReasonMissing,
  };
}

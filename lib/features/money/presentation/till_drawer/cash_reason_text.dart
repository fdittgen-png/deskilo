// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4514 -- the words of a cash reason: a built-in one in the reader's language, a business's own one by the name it was
// typed with. A reason stored before the reasons were records is said as it was stored.
import '../../../../l10n/app_localizations.dart';
import '../../domain/cash_reason.dart';

/// The name of [reason] for the reader.
String cashReasonLabel(AppLocalizations l10n, CashReason reason) =>
    reason.builtin
    ? _builtinName(l10n, reason.code) ?? reason.code
    : (reason.name ?? reason.code);

/// The words of a reason stored as [stored] (a code, or the text an entry was recorded with before).
String cashReasonText(
  AppLocalizations l10n,
  String stored,
  Iterable<CashReason> reasons,
) {
  for (final r in reasons) {
    if (r.code == stored) return cashReasonLabel(l10n, r);
  }
  return _builtinName(l10n, stored) ?? stored;
}

String? _builtinName(AppLocalizations l10n, String code) => switch (BuiltinCashReason.of(code)) {
  BuiltinCashReason.change => l10n.tillCashReasonChange,
  BuiltinCashReason.expense => l10n.tillCashReasonExpense,
  BuiltinCashReason.countingError => l10n.tillCashReasonCountingError,
  BuiltinCashReason.other => l10n.tillCashReasonOther,
  BuiltinCashReason.unknown => null,
};

/// The name of [process].
String cashReasonProcessLabel(
  AppLocalizations l10n,
  CashReasonProcess process,
) => switch (process) {
  CashReasonProcess.paidIn => l10n.tillDrawerEntryPaidIn,
  CashReasonProcess.paidOut => l10n.tillDrawerEntryPaidOut,
  CashReasonProcess.countDifference => l10n.tillCashReasonCountDifference,
};

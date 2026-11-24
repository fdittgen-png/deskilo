// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4413 -- the bank statement codes (0603, 0650, 0657, 0660) and the
// accounting connection codes (#2370) with their words, registered with the
// core table (lib/core/trace/feature_refusals.dart) at start.
import '../../../core/codes/dk_code.dart';
import '../../../core/trace/feature_refusals.dart';
import '../../../l10n/app_localizations.dart';

/// Registers the bank's and the accounting connection's words.
void registerMoneyRefusals() => FeatureRefusals.register(_moneyWords);

String? _moneyWords(AppLocalizations l10n, String code, String? details) =>
    switch (code) {
      // DKA01: the issuer was connected meanwhile, by someone else.
      DkCode.dka01 => l10n.refusalChangedMeanwhile,
      DkCode.dka02 => l10n.refusalAccountingClosed,
      DkCode.dka03 => l10n.refusalAccountingValue,
      DkCode.dkb01 => l10n.refusalBankLineDecided,
      DkCode.dkb02 => l10n.refusalBankLineRefused,
      DkCode.dkb03 => l10n.refusalBankFileRefused,
      DkCode.dkb04 => l10n.refusalBankMatchBeyondLink,
      DkCode.dkb05 => l10n.refusalBankMatchSeveralPayments,
      DkCode.dkb06 => l10n.refusalBankMatchClosedPeriod,
      DkCode.dkb07 => l10n.refusalBankMatchUndoLaterFirst,
      _ => null,
    };

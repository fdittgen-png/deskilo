// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 -- the till's words: what an operation of the counter is called, and what a refusal of the till says. A
// refusal is the server's (the counter's DKT codes have their sentences in `knownRefusalText`); what the till refuses
// by itself (cash short of the total) is said here.
import '../../../core/trace/refusal_text.dart';
import '../../../l10n/app_localizations.dart';
import 'till_session.dart';

/// The name of a counter operation as a country's registry knows it.
String tillOperationName(AppLocalizations l10n, String operation) => switch (operation) {
  'issue_receipt' => l10n.tillOpIssueReceipt,
  'correct_receipt' => l10n.tillOpCorrectReceipt,
  'reconcile_tender' => l10n.tillOpReconcileTender,
  'sign_fiscal' => l10n.tillOpSignFiscal,
  'export_fiscal' => l10n.tillOpExportFiscal,
  _ => operation,
};

/// What the last act's [problem] says, in words: the till's own check, the server's refusal, or a plain failure.
String tillProblemText(AppLocalizations l10n, Object problem) {
  if (problem is String) return problem;
  if (problem is TillCashShort) return l10n.tillCashShort;
  return knownRefusalText(l10n, problem) ?? l10n.tillFailed;
}

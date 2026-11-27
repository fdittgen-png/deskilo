// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The words of a loss: why goods were written off, as the take-out sheet offers it and as a movement shows it.
import '../../../l10n/app_localizations.dart';
import '../domain/stock_operations.dart';

/// The words of a loss's cause, by the server's key; a cause this app does not know is shown as it came.
String stockLossCauseText(AppLocalizations l10n, String cause) => switch (cause) {
  'expired' => l10n.stockLossCauseExpired,
  'damaged' => l10n.stockLossCauseDamaged,
  'spoiled' => l10n.stockLossCauseSpoiled,
  'missing' => l10n.stockLossCauseMissing,
  'other' => l10n.stockLossCauseOther,
  _ => cause,
};

/// What a problem with a loss says under its field: the field it belongs to and the sentence.
(String, String) stockLossProblemText(AppLocalizations l10n, StockLossProblem problem) => switch (problem) {
  StockLossProblem.causeMissing => ('cause', l10n.stockLossCauseRequired),
  StockLossProblem.noteTooLong => ('note', l10n.stockLossNoteTooLong),
};

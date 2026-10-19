// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1923 C / #2579 — what a refused saved-view write says.
import '../../../../l10n/app_localizations.dart';
import '../../domain/bi_saved_view.dart';

String biViewFailureText(AppLocalizations l10n, BiViewFailure f) => switch (f) {
  BiViewFailure.stale => l10n.biViewStale,
  BiViewFailure.nameTaken => l10n.biViewNameTaken,
  BiViewFailure.forbidden => l10n.biViewForbidden,
  BiViewFailure.invalid => l10n.biViewInvalid,
  BiViewFailure.unsupported => l10n.biViewUnsupported,
};

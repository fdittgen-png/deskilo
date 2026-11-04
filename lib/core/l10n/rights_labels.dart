// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1915, #3278 — the words for a rights request's kind and where it stands,
// shared by the member's own list and the personal data admin's screen. They
// take plain values, so neither feature imports the other.
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

/// The kind of a rights request, in the reader's language.
String rightsKindLabel(AppLocalizations l10n, String kind) => switch (kind) {
  'access' => l10n.rightsKindAccess,
  'portability' => l10n.rightsKindPortability,
  'rectification' => l10n.rightsKindRectification,
  'restriction' => l10n.rightsKindRestriction,
  'objection' => l10n.rightsKindObjection,
  _ => l10n.rightsKindErasure,
};

/// Where a request stands: received (by when it is answered), extended (the
/// new date and its reason), completed, or refused (with the reason).
String rightsStatusLabel(
  AppLocalizations l10n, {
  required String status,
  required DateTime dueOn,
  required DateTime answerBy,
  required DateFormat date,
  String? extensionReason,
  String? refusalReason,
}) => switch (status) {
  'extended' => l10n.rightsStatusExtended(
    date.format(answerBy),
    extensionReason ?? '',
  ),
  'completed' => l10n.rightsStatusCompleted,
  'refused' => l10n.rightsStatusRefused(refusalReason ?? ''),
  _ => l10n.rightsStatusReceived(date.format(dueOn)),
};

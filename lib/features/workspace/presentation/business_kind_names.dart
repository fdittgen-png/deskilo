// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3553 — the name of a business kind, wherever the app shows one: the
// settings sheet, the public page's preview, Discover. A kind this app does
// not know yet has no name here: a card shows nothing rather than a code.
import '../../../l10n/app_localizations.dart';

/// The name of the kind [code], or null for a kind this app does not know.
String? businessKindLabel(AppLocalizations l10n, String code) => switch (code) {
  'coworking' => l10n.businessKindNameCoworking,
  'studio' => l10n.businessKindNameStudio,
  'practice' => l10n.businessKindNamePractice,
  'salon' => l10n.businessKindNameSalon,
  'service' => l10n.businessKindNameService,
  _ => null,
};

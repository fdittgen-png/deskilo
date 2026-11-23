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
  'freelancer' => l10n.businessKindNameFreelancer,
  'shop' => l10n.businessKindNameShop,
  'service' => l10n.businessKindNameService,
  _ => null,
};

/// #3554 — the kinds Discover offers to narrow by, in its order: the app's
/// own catalogue, never the kinds the loaded results happen to contain (a
/// kind beyond the first page must still be choosable).
const List<String> discoverableBusinessKinds = [
  'coworking',
  'studio',
  'practice',
  'salon',
  'freelancer',
  'shop',
  'service',
];

/// The label of Discover's chip for the kind [code] (a plural), or null for
/// a kind this app does not know.
String? businessKindChipLabel(AppLocalizations l10n, String code) =>
    switch (code) {
      'coworking' => l10n.discoveryKindCoworking,
      'studio' => l10n.discoveryKindStudios,
      'practice' => l10n.discoveryKindPractices,
      'salon' => l10n.discoveryKindSalons,
      'freelancer' => l10n.discoveryKindFreelancers,
      'shop' => l10n.discoveryKindShops,
      'service' => l10n.discoveryKindServices,
      _ => null,
    };

/// #4365 -- the name of a type of shop (`grocery`, `bakery`, `butcher`, `florist`, `corner_shop`).
String shopTypeLabel(AppLocalizations l10n, String type) => switch (type) {
  'bakery' => l10n.shopTypeBakery,
  'butcher' => l10n.shopTypeButcher,
  'florist' => l10n.shopTypeFlorist,
  'corner_shop' => l10n.shopTypeCornerShop,
  _ => l10n.shopTypeGrocery,
};

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 -- the vocabulary of a feature's registry entry (its tier, its surface
// and the entry itself), moved out of workspace_feature.dart so that file stays
// the list of features. workspace_feature.dart exports this, so every import of
// it still sees these names.
import 'workspace_feature.dart';

/// #1063 — what a workspace meets on its FIRST day, and what it has to
/// ask for.
///
/// The registry has a hundred entries. Every one of them is behind a
/// flag, which is the right architecture; what was wrong is that the
/// default was "all of it", so a fifteen-person community met VAT
/// groups, positioned report layouts, environment pairs and deployment
/// beside the six things it actually needed.
///
/// This is a property, not a mechanism. [core] is what every deployment
/// needs — the floor plan, reservations, members, memberships, the
/// ledger, payments, invoices, basic administration. [platform] is what
/// only a sophisticated operator needs, and a new workspace starts
/// without it.
///
/// It changes NO existing workspace: the tier decides what
/// [defaultFeatureFlagsForNewWorkspace] writes AT CREATION, and a
/// workspace that already exists keeps exactly the flags it has.
/// A migration that silently switched a live workspace's features off
/// would be a data-loss bug wearing a feature flag.
/// #1221 — WHERE a feature shows up, which is the question an owner
/// actually asks about a list of a hundred switches. The tier answers
/// "should I have this"; the surface answers "where would I see it".
///
/// The screen groups by this, so a surface is a place in the app and
/// never a department: an owner looking for the VAT one thinks "Money",
/// not "finance domain".
enum FeatureSurface {
  reserve,
  calendar,
  members,
  money,
  messages,
  documents,
  kiosk,
  reports,
  settings,

  /// No single home — it changes how the whole app behaves.
  everywhere,
}

enum FeatureTier {
  /// Day one, every deployment.
  core,

  /// Asked for, never assumed.
  platform,
}

/// Registry entry of one toggleable feature (mirrors tankstellen's
/// manifest). [requires] expresses the feature HIERARCHY: a feature is
/// only EFFECTIVE while its whole prerequisite chain is enabled — the
/// Features screen renders children indented under their parent and
/// [effectiveFeatures] drops orphans, so switching a parent off takes
/// its whole subtree out of the app without erasing the owner's stored
/// child choices.
class FeatureManifestEntry {
  const FeatureManifestEntry({
    required this.feature,
    required this.tier,
    required this.surface,
    this.defaultOn = true,
    this.requires,
    this.availableIn,
    this.since,
  });

  final WorkspaceFeature feature;

  /// #1063 — whether a NEW workspace starts with this. Required, with no
  /// default, so that a flag cannot be added without somebody deciding
  /// which tier it belongs to.
  final FeatureTier tier;

  /// #1221 — where in the app this shows up. Required, with no default,
  /// for the same reason [tier] is: a flag cannot arrive without
  /// somebody saying where its owner would go looking for it.
  final FeatureSurface surface;

  /// Whether the feature is enabled when the workspace row carries no
  /// override for it.
  final bool defaultOn;

  /// The parent feature this one needs, or null for a root feature.
  final WorkspaceFeature? requires;

  /// #2454 — the countries (ISO 3166-1 alpha-2, or [featureCountriesEu])
  /// the feature is available in; null means every country. Derived, never
  /// stored: the owner's switch is kept when the country does not match.
  final Set<String>? availableIn;

  /// #3729 (K2) — the schema number of the migration that brought this
  /// feature's server side: an installation below it does not offer the
  /// feature (menu, routes, assistants) instead of failing at the first call.
  /// Null means "any". Not mirrored in `feature_registry()`: the
  /// installation's own number is the server's side of the comparison.
  /// Declared when the feature is written, while its author knows it.
  final int? since;
}

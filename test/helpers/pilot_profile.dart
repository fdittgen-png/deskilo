// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The existing-community pilot's feature profile (#1974), shared by the tests
// that pin it. Test files may not import each other, so it lives here.
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';

/// The features the pilot excludes (#1447): OFF, with everything that needs them.
const pilotExcluded = <WorkspaceFeature>{
  WorkspaceFeature.onlinePayments,
  WorkspaceFeature.mcpAccess,
  WorkspaceFeature.accountingBook,
  WorkspaceFeature.guestParticipation,
  WorkspaceFeature.publicListings,
};

/// What the pilot needs ON beside the core, each one platform-tier (so an
/// absent key is OFF since #2566) and each named by evidence:
///  * `invoicing` and `expenseRepartition`: the flags the pilot fixtures
///    160_pilot_reconciliation and 164_invoice_feature_guards enable for the
///    subscription/usage -> approved expense -> manual payment -> statement
///    journey;
///  * `supplyClassification` and `configurableSettings`: named by the
///    2026-10-14 amendment of #1974.
/// Each brings its requirement chain. A feature the journey turns out to need
/// is added here by a reviewed change.
const pilotRequiredOn = <WorkspaceFeature>{
  WorkspaceFeature.invoicing,
  WorkspaceFeature.expenseRepartition,
  WorkspaceFeature.supplyClassification,
  WorkspaceFeature.configurableSettings,
};

/// Every feature whose requirement chain passes through [feature].
Set<WorkspaceFeature> dependentsOf(WorkspaceFeature feature) => {
      for (final f in WorkspaceFeature.values)
        if (requirementChain(f).contains(feature)) f,
    };

/// The profile as stored: every excluded feature explicitly off, every
/// required one explicitly on with what it needs.
Map<String, bool> pilotProfile() => {
      for (final f in pilotExcluded) f.dbKey: false,
      for (final f in pilotRequiredOn)
        for (final e in featureFlagsToggleDelta(feature: f, value: true).entries)
          e.key.dbKey: e.value,
    };

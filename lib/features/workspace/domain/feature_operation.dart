// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../../core/instance/schema_compatibility.dart';
import 'feature_lifecycle.dart';
import 'workspace_feature.dart';

/// #1851 — what switching a feature off actually stops.
///
/// Every gated operation belongs to one class. Off stops NEW business
/// ([acceptNew]); the work already under way can still be read, answered,
/// settled or closed ([serviceExisting]) by whoever could do it before; a
/// path judged unsafe is shut whatever the flag says ([suspended]).
///
/// The server half is `public.feature_operation_allowed` (0324); both
/// answer the matrix pinned in feature_operation_test.dart and pgTAP 110.
/// The class never decides WHO may act — that stays with the permission
/// checks of each operation.
enum FeatureOperation {
  acceptNew('accept_new'),
  serviceExisting('service_existing'),
  suspended('suspended');

  const FeatureOperation(this.wire);

  /// The name the server functions use.
  final String wire;
}

/// A wire name back to its class; null when unknown, as on the server.
FeatureOperation? featureOperationFromWire(String? wire) {
  for (final o in FeatureOperation.values) {
    if (o.wire == wire) return o;
  }
  return null;
}

/// May [operation] of [feature] run, given the EFFECTIVE set? A null
/// [feature] is a key this build does not know: it takes nothing new.
bool featureOperationAllowed({
  required Set<WorkspaceFeature> effective,
  required WorkspaceFeature? feature,
  required FeatureOperation operation,
}) => switch (operation) {
  FeatureOperation.acceptNew => feature != null && effective.contains(feature),
  FeatureOperation.serviceExisting => true,
  FeatureOperation.suspended => false,
};

/// The server operations each feature classifies, by function name; a
/// function whose class depends on what it is asked to do names each
/// branch after a `#` (`assign_workspace_role#revoke`). A feature listed
/// here with a service-existing operation keeps its existing work
/// serviceable when it is switched off; the Features screen says so on
/// its row. The newest migration that gates each function must use
/// exactly these classes (lint in feature_operation_test.dart).
///
/// Settlement callbacks (payment webhooks, refunds) carry no feature
/// gate at all: money already committed is always settled.
const Map<WorkspaceFeature, Map<String, FeatureOperation>>
featureOperationClasses = {
  // 0324
  WorkspaceFeature.spaceInquiries: {
    'start_space_inquiry': FeatureOperation.acceptNew,
    'send_inquiry_message': FeatureOperation.serviceExisting,
    'my_inbox': FeatureOperation.serviceExisting,
  },
  // 0356 (#1851 C)
  WorkspaceFeature.customRoles: {
    'assign_workspace_role#give': FeatureOperation.acceptNew,
    'assign_workspace_role#revoke': FeatureOperation.serviceExisting,
  },
  WorkspaceFeature.adminSeatBlocking: {
    'set_seat_block#place': FeatureOperation.acceptNew,
    'set_seat_block#lift': FeatureOperation.serviceExisting,
  },
  WorkspaceFeature.autoCheckInOut: {
    'sweep_day_end': FeatureOperation.acceptNew,
  },
};

/// The server schema from which [feature]'s classes hold: an older server
/// still stops existing work with the switch, so nothing may claim
/// otherwise against it.
const Map<WorkspaceFeature, int> featureOperationSince = {
  WorkspaceFeature.spaceInquiries: 324,
  WorkspaceFeature.customRoles: 356,
  WorkspaceFeature.adminSeatBlocking: 356,
  WorkspaceFeature.autoCheckInOut: 356,
};

/// #1851 C — may the app say that switching [feature] off leaves its open
/// work serviceable, given how the server compares with this build? Only
/// a server at least as new as this build (which needs every class's
/// migration) runs the classes; an older one, or one that could not be
/// asked, still stops existing work with the switch.
bool serverKeepsExistingWork(
  WorkspaceFeature feature,
  SchemaCompatibility? compatibility,
) =>
    (compatibility == SchemaCompatibility.current ||
        compatibility == SchemaCompatibility.ahead) &&
    requiredSchemaVersion >= (featureOperationSince[feature] ?? 1 << 30);

/// Does switching [feature] off leave existing work serviceable?
bool featureKeepsExistingWork(WorkspaceFeature feature) =>
    featureOperationClasses[feature]?.values.contains(
      FeatureOperation.serviceExisting,
    ) ??
    false;

/// #1851 — the explicit opt-in: switching ON an alpha or beta feature
/// asks the owner to accept its limitations first. It reads maturity to
/// ASK, never to open anything: the stored flag the owner then writes is
/// what every gate reads, and `effectiveFeatures` does not change.
bool featureNeedsOptIn(
  WorkspaceFeature feature, {
  Map<WorkspaceFeature, FeatureAssessment> assessments = featureAssessments,
}) {
  final maturity = featureAssessmentOf(
    feature,
    assessments: assessments,
  ).maturity;
  return maturity == FeatureMaturity.alpha || maturity == FeatureMaturity.beta;
}

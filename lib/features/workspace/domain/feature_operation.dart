// SPDX-License-Identifier: AGPL-3.0-or-later

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

/// The server operations each feature classifies, by function name. A
/// feature listed here keeps its existing work serviceable when it is
/// switched off; the Features screen says so on its row. The migration
/// that gates these functions must use the same class (lint in
/// feature_operation_test.dart).
const Map<WorkspaceFeature, Map<String, FeatureOperation>>
featureOperationClasses = {
  WorkspaceFeature.spaceInquiries: {
    'start_space_inquiry': FeatureOperation.acceptNew,
    'send_inquiry_message': FeatureOperation.serviceExisting,
    'my_inbox': FeatureOperation.serviceExisting,
  },
};

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

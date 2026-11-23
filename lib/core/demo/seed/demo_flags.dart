// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2313 — the demo shows what the product can do. The space a visitor
// lands in (ws-1) therefore has EVERY feature of the registry switched on,
// derived from `featureManifest` so a feature added later is on in the
// demo the day it ships — and `demo_scenarios_test.dart` then asks for the
// scenario that demonstrates it.
//
// Left off, each for a reason a visitor could not work around:
//   * `mcpAccess` (and `webMcp` under it) — an assistant connects to a
//     server's MCP endpoint over OAuth; the demo has no server, no
//     endpoint and no account to authorise.
//   * `recordingPrivacy` — filming mode replaces every member by an
//     invented person at the data seam; the demo's people are invented
//     already, and the substitution would hide the cast the guides and
//     the scenarios are written about.
//
// #2566 — every key is stored explicitly: a key absent from the map is
// off for a platform feature.
//
// The second space (ws-2, Leipzig) starts the way a NEW space starts —
// core features on, every platform feature off — so it has no VAT, no
// accounting book and no purchases: a basic space beside a complete one.
import 'package:meta/meta.dart';

import '../../../features/workspace/domain/workspace_feature.dart';

/// The features the demo's main space keeps off, and why.
@visibleForTesting
const Map<WorkspaceFeature, String> demoFeaturesLeftOff = {
  WorkspaceFeature.stockScanning:
      '#4359: the scanning of the goods sheets is the client slice; its Demo scenario '
      'arrives with the screens, which turn the feature on and add it',
  WorkspaceFeature.stockTags:
      '#4362: the server side (tags, pieces, the resolver) is delivered first; the '
      "Demo's tagged gift basket, apple crate and places arrive with its screens, "
      'which turn the feature on and add their scenario',
  WorkspaceFeature.mtdSubmission:
      'UK only: off in the head, on in the London house (ws-3), where its '
      'scenario is performed (#4009); left off in the other houses',
  WorkspaceFeature.recordingPrivacy:
      'recording privacy is the mode itself, not a switch beside it: on, '
      'every name the Demo prints is replaced by an invented one from the '
      'first screen, so the Demo keeps it off and the owner can turn it on '
      'from Features for a session, the cast returning when it is turned off',
};

/// ws-1: every feature on, except [demoFeaturesLeftOff] and anything whose
/// prerequisite chain runs through one of them.
final Map<String, dynamic> demoFeatureFlags = {
  for (final feature in featureManifest.keys)
    feature.dbKey:
        !demoFeaturesLeftOff.containsKey(feature) &&
        !requirementChain(feature).any(demoFeaturesLeftOff.containsKey),
};

/// #3962 — the other Demo businesses (London, New York, the trade cities)
/// hold the main space's features but no assistant: the one connected
/// assistant and its requests belong to the reference business.
final Map<String, Object?> demoOtherSpacesFeatureFlags = {
  ...demoFeatureFlags,
  WorkspaceFeature.mcpAccess.dbKey: false,
  WorkspaceFeature.webMcp.dbKey: false,
};

/// ws-2: exactly what a space created today is given.
final Map<String, bool> demoSecondSpaceFeatureFlags =
    defaultFeatureFlagsForNewWorkspace();

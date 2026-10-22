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
  WorkspaceFeature.mcpAccess:
      'an assistant needs a server endpoint and an OAuth account',
  WorkspaceFeature.webMcp: 'needs mcpAccess, which needs a server',
  WorkspaceFeature.recordingPrivacy:
      'filming mode would replace the invented cast by other invented '
      'people on every screen',
};

/// ws-1: every feature on, except [demoFeaturesLeftOff] and anything whose
/// prerequisite chain runs through one of them.
final Map<String, dynamic> demoFeatureFlags = {
  for (final feature in featureManifest.keys)
    feature.dbKey:
        !demoFeaturesLeftOff.containsKey(feature) &&
        !requirementChain(feature).any(demoFeaturesLeftOff.containsKey),
};

/// ws-2: exactly what a space created today is given.
final Map<String, bool> demoSecondSpaceFeatureFlags =
    defaultFeatureFlagsForNewWorkspace();

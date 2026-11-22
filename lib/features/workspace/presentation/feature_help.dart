// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4350 -- the features whose row on the Features screen carries a help symbol: the guide section that
// says what switching the feature on adds and where its pages are afterwards.
import '../../../core/help/help_anchors.dart';
import '../domain/workspace_feature.dart';

/// Feature -> the guide section its row opens.
const Map<WorkspaceFeature, String> featureHelpAnchors = {
  // the goods ledger: the Stock menu, with its items, places, deliveries and moves
  WorkspaceFeature.stockManagement: HelpAnchor.moneyStock,
};

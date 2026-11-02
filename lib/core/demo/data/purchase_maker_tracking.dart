// SPDX-License-Identifier: AGPL-3.0-or-later

/// Track both maker and submitter across Demo persona changes.
mixin DemoPurchaseMakerTracking {
  String Function() get actor;
  /// Demo commands recheck access independently of the displayed action.
  bool Function(String workspaceId)? mayDecide;

  void requireDemoDecisionAccess(String workspaceId) {
    if (mayDecide?.call(workspaceId) == false) {
      throw StateError('purchase decision is not available');
    }
  }

  final Map<String, String> billMaker = {};
  final Map<String, String> billSubmitter = {};

  bool isDemoMaker(String id) =>
      billMaker[id] == actor() || billSubmitter[id] == actor();
}

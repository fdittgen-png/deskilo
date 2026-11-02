// SPDX-License-Identifier: AGPL-3.0-or-later

/// Track both maker and submitter across Demo persona changes.
mixin DemoPurchaseMakerTracking {
  String Function() get actor;
  final Map<String, String> billMaker = {};
  final Map<String, String> billSubmitter = {};

  bool isDemoMaker(String id) =>
      billMaker[id] == actor() || billSubmitter[id] == actor();
}

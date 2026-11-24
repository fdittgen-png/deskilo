// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4442 -- the Demo keeps the units of measure of each business in memory, with the server's own rules (0951). One list per
// business id, made when the Demo's overrides are built; a unit that [itemUnits] counts goods in is used, so it keeps its
// dimension and factor and cannot be archived.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../features/stock/providers/workspace_units_providers.dart';
import 'data/demo_workspace_units.dart';

List<Override> demoUnitOverrides(Iterable<String> Function(Ref ref) itemUnits) {
  final units = DemoWorkspaceUnits();
  return [workspaceUnitsProvider.overrideWith((ref) => units..usedBy = (workspaceId, code) => itemUnits(ref).contains(code))];
}

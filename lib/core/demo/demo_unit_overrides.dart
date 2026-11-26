// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4442 -- the Demo keeps the units of measure of each business in memory, with the server's own rules (0951). One list per
// business id, made when the Demo's overrides are built; a unit that [itemUnits] counts goods in is used, so it keeps its
// dimension and factor and cannot be archived. #4479 -- and their general conversions, the same way (0968): a unit made, or one whose
// factor changes, gets its conversions to the units of its dimension.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../features/stock/providers/workspace_units_providers.dart';
import 'data/demo_unit_conversions.dart';
import 'data/demo_workspace_units.dart';

List<Override> demoUnitOverrides(Iterable<String> Function(Ref ref) itemUnits, bool Function(Ref ref, String workspaceId, String code) packages) {
  final units = DemoWorkspaceUnits();
  final conversions = DemoUnitConversions();
  return [
    workspaceUnitsProvider.overrideWith(
      (ref) => units
        ..usedBy = ((workspaceId, code) => itemUnits(ref).contains(code))
        ..packages = ((workspaceId, code) => packages(ref, workspaceId, code))
        ..onSaved = conversions.unitSaved,
    ),
    unitConversionsProvider.overrideWith(
      (ref) => conversions..unitsOf = units.heldBy,
    ),
  ];
}

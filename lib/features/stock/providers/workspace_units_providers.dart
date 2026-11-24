// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/trace/trace_logger.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../data/supabase_workspace_units.dart';
import '../domain/workspace_units.dart';

/// #4442 -- the units of measure of the selected business (the Demo keeps its own in memory).
final workspaceUnitsProvider = Provider<WorkspaceUnits>((ref) => SupabaseWorkspaceUnits(ref.watch(selectedWorkspaceClientProvider)));

/// #4442 -- the units of [workspaceId], archived ones included, for the screens and the pickers.
final workspaceUnitListProvider = FutureProvider.autoDispose.family<List<WorkspaceUnit>, String>(
  (ref, workspaceId) => ref.watch(workspaceUnitsProvider).units(workspaceId),
  retry: (_, _) => null,
);

/// #4442 -- the units a line of a quote or an invoice may be sold in besides the ones it always offers: the business's own, not
/// archived, while the feature is on (none while it is off). A read that fails offers none, never an error.
final lineUnitsProvider = FutureProvider.family<List<WorkspaceUnit>, String>((ref, workspaceId) async {
  if (!ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.unitsOfMeasure)) return const <WorkspaceUnit>[];
  try {
    return pickableUnits(await ref.watch(workspaceUnitListProvider(workspaceId).future), unitsOn: true);
  } on Object catch (e, st) {
    TraceLogger.instance.warn('money', 'the units could not be read for a line', error: e, stackTrace: st);
    return const <WorkspaceUnit>[];
  }
});

/// #4442 -- the units a picker of what an item is counted in offers for [workspaceId]: the six of before while the feature is off,
/// every unit that is not archived when it is on. A business whose units cannot be read is offered the six of before (the picker
/// never waits on, or fails with, a read it can do without); [keep] is the unit the item already has.
Future<List<WorkspaceUnit>> pickableUnitsOf(WidgetRef ref, String workspaceId, {String? keep}) async {
  final on = ref.read(enabledFeaturesSyncProvider).contains(WorkspaceFeature.unitsOfMeasure);
  if (!on) return pickableUnits(builtInUnits, unitsOn: false, keep: keep);
  try {
    return pickableUnits(await ref.read(workspaceUnitListProvider(workspaceId).future), unitsOn: true, keep: keep);
  } on Object catch (e, st) {
    TraceLogger.instance.warn('stock', 'the units could not be read for a picker', error: e, stackTrace: st);
    return pickableUnits(builtInUnits, unitsOn: false, keep: keep);
  }
}

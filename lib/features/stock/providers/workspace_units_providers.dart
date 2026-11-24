// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

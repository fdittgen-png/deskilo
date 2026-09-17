// SPDX-License-Identifier: 0BSD
//
// #1307 S4 — the provenance half of the Supabase repository, on its own
// file like the template library (#1120): the repository is at its length
// budget, and the rule is to extract, not to raise the number.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/work_hours_provenance.dart';

mixin SupabaseWorkspaceProvenance {
  SupabaseClient get client;

  Future<WorkHoursProvenance> fetchWorkHoursProvenance(
      String workspaceId) async {
    final json = await client.rpc<dynamic>('work_hours_provenance',
        params: {'p_workspace_id': workspaceId});
    return WorkHoursProvenance.fromJson(
        Map<String, dynamic>.from(json as Map? ?? const <String, dynamic>{}));
  }

  Future<void> resetWorkHoursToDefault(String workspaceId) =>
      client.rpc<dynamic>('reset_work_hours',
          params: {'p_workspace_id': workspaceId});
}

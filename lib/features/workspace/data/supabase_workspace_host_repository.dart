// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2562 C2c -- the enrolled workspace hosts, read on the personal home in
// the person's native session (`my_workspace_hosts_v1`, first-party only).
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/workspace_host.dart';

class SupabaseWorkspaceHostRepository implements WorkspaceHostRepository {
  const SupabaseWorkspaceHostRepository(this._personal);

  /// The personal home's client: never a workspace host's.
  final SupabaseClient _personal;

  @override
  Future<WorkspaceHosts> fetchHosts() async =>
      WorkspaceHosts.parse(await _personal.rpc<Object?>('my_workspace_hosts_v1'));
}

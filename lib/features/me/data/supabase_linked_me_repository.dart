// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/backend/connected_installations.dart';
import '../../../core/data/system_columns.dart';
import '../domain/linked_me_repository.dart';
import '../domain/my_spaces.dart';
import '../domain/visibility.dart';
import 'visibility_rpc.dart';

/// [LinkedMeRepository] over the sessions [ConnectedInstallations] keeps
/// for the other servers: every call is made with that server's client.
class SupabaseLinkedMeRepository implements LinkedMeRepository {
  const SupabaseLinkedMeRepository(this._connections);

  final ConnectedInstallations _connections;

  @override
  Future<MyVisibility> visibility(String source) =>
      _connections.use(source, readMyVisibility);

  @override
  Future<void> setVisibility(
    String source,
    VisibilityField field,
    FieldAudience audience,
  ) => _connections.use(
    source,
    (client) => writeVisibility(client, field, audience),
  );

  @override
  Future<List<LinkedSpace>> spaces(String source) => _connections.use(source, (
    client,
  ) async {
    final user = client.auth.currentUser?.id;
    if (user == null) return const <LinkedSpace>[];
    // RLS answers with the spaces this account may read there; the
    // membership rows say how it stands in each.
    final spaces = await client.from('workspaces').select();
    final members = await client
        .from('members')
        .select('workspace_id, status, is_owner, is_admin')
        .eq('user_id', user);
    final byWorkspace = {
      for (final m in members) m['workspace_id'] as String: m,
    };
    return [
      for (final row in spaces)
        LinkedSpace(
          id: row['id'] as String,
          name: row['name'] as String? ?? '',
          pairId: row['pair_id'] as String? ?? '',
          environment: row['environment'] as String? ?? '',
          standing: standingOf(byWorkspace[row['id']]?['status'] as String?),
          isOwner: byWorkspace[row['id']]?['is_owner'] == true,
          isAdmin: byWorkspace[row['id']]?['is_admin'] == true,
          system: SystemColumns.fromRow(row),
        ),
    ];
  });
}

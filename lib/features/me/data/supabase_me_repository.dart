// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/connected_installations.dart';
import '../../../core/data/system_columns.dart';
import '../domain/me_repository.dart';
import '../domain/my_spaces.dart';
import '../domain/public_person.dart';
import '../domain/visibility.dart';

/// #1823 — [MeRepository] over this server's client, and over the linked
/// sessions [ConnectedInstallations] keeps for the other servers.
class SupabaseMeRepository implements MeRepository {
  const SupabaseMeRepository(this._client, this._connections);

  final SupabaseClient _client;
  final ConnectedInstallations? _connections;

  Map<String, dynamic> _object(Object? raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

  @override
  Future<void> leaveSpace(String workspaceId) => _client.rpc<void>(
        'leave_workspace',
        params: {'p_workspace_id': workspaceId},
      );

  @override
  Future<MyVisibility> myVisibility() async =>
      MyVisibility.fromJson(_object(await _client.rpc<dynamic>('my_visibility')));

  @override
  Future<void> setVisibility(
    VisibilityField field,
    FieldAudience audience,
  ) =>
      _client.rpc<void>('set_visibility', params: {
        'p_field': field.wire,
        'p_audience': audience.audience.wire,
        'p_workspaces': audience.audience == VisibilityAudience.chosenSpaces
            ? audience.workspaces
            : null,
      });

  @override
  Future<void> setAbout(String profession, String bio) => _client.rpc<void>(
        'set_my_about',
        params: {'p_profession': profession, 'p_bio': bio},
      );

  @override
  Future<AccountView> previewMyAccount(PreviewAudience audience) async =>
      AccountView.fromJson(_object(await _client
          .rpc<dynamic>('preview_my_account', params: {'p_as': audience.wire})));

  @override
  Future<bool> myPublicProfile() async =>
      _object(await _client.rpc<dynamic>('my_public_profile'))['published'] ==
      true;

  @override
  Future<void> setPublicProfile(bool publish) => _client.rpc<void>(
        'set_public_profile',
        params: {'p_publish': publish},
      );

  @override
  Future<PublicPerson?> publicPerson(String userId) async {
    // 0390 — the public card, readable signed in or not; no row = not public.
    final row = await _client
        .from('public_person_cards')
        .select('name, profession, bio')
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : PublicPerson.fromJson(row);
  }

  @override
  Future<AccountView> visibleAccount(String userId) async =>
      AccountView.fromJson(_object(await _client
          .rpc<dynamic>('visible_account', params: {'p_user_id': userId})));

  @override
  Future<MyVisibility> myVisibilityOn(String source) {
    final connections = _connections;
    if (connections == null) return Future.value(MyVisibility.defaults);
    return connections.use(source, (client) async => MyVisibility.fromJson(
        _object(await client.rpc<dynamic>('my_visibility'))));
  }

  @override
  Future<void> setVisibilityOn(
    String source,
    VisibilityField field,
    FieldAudience audience,
  ) {
    final connections = _connections;
    if (connections == null) throw StateError('no linked server');
    return connections.use(source, (client) => client.rpc<void>(
          'set_visibility',
          params: {
            'p_field': field.wire,
            'p_audience': audience.audience.wire,
            'p_workspaces': null,
          },
        ));
  }

  @override
  Future<List<LinkedSpace>> spacesOn(String source) {
    final connections = _connections;
    if (connections == null) return Future.value(const []);
    return connections.use(source, (client) async {
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
}

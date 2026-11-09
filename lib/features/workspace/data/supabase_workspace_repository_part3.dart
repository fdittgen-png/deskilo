// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'supabase_workspace_repository.dart';

// #2386 — part 3 of SupabaseWorkspaceRepository, split out of supabase_workspace_repository.dart so no
// file holds the whole class.
extension _SupabaseWorkspaceRepositoryPart3 on SupabaseWorkspaceRepository {

  Future<void> _requestRoleChangeImpl(
    String workspaceId, {
    required String memberId,
    required bool makeAdmin,
  }) async {
    await _client.rpc<dynamic>('request_role_change', params: {
      'p_workspace_id': workspaceId,
      'p_target_member_id': memberId,
      'p_make_admin': makeAdmin,
    });
  }

  Future<String> _setWorkspaceCodeImpl(String workspaceId, String code) async {
    final result = await _client.rpc<dynamic>('set_workspace_code', params: {
      'p_workspace_id': workspaceId,
      'p_code': code,
    });
    return result as String;
  }

  

  

  

  

  

  

  

  

  Future<NewMemberDefaults> _fetchNewMemberDefaultsImpl(String workspaceId) async {
    final row = await _client
        .from('workspaces')
        .select('billing_rules')
        .eq('id', workspaceId)
        .single();
    return NewMemberDefaults.fromRules(
        row['billing_rules'] as Map<String, dynamic>?);
  }

  Future<void> _setNewMemberDefaultsImpl(
    String workspaceId,
    NewMemberDefaults defaults,
  ) async {
    // Keyed, so the merge happens in the database and a sibling billing
    // rule survives (#1089, and 0221's `set_billing_rule`).
    await _client.rpc<dynamic>('set_billing_rule', params: {
      'p_workspace_id': workspaceId,
      'p_key': newMemberDefaultsKey,
      'p_value': defaults.toValue(),
    });
  }

  Future<Map<String, dynamic>> _fetchLexiconImpl(String workspaceId) async {
    final row = await _client
        .from('workspaces')
        .select('lexicon')
        .eq('id', workspaceId)
        .single();
    return row['lexicon'] as Map<String, dynamic>? ?? const {};
  }

  Future<void> _setLexiconTermImpl(
    String workspaceId,
    String locale,
    String key,
    String? text,
  ) async {
    // Keyed, so the merge happens in the database: a second editor
    // cannot revert the first, and the other locales survive (#1089).
    await _client.rpc<dynamic>('set_workspace_lexicon_term', params: {
      'p_workspace_id': workspaceId,
      'p_locale': locale,
      'p_key': key,
      'p_text': text,
    });
  }

  Future<void> _setWorkspaceEmblemImpl(String workspaceId, Uint8List png) async {
    await _client.storage
        .from('floor-plans')
        .uploadBinary(
          SupabaseWorkspaceRepository.emblemPath(workspaceId),
          png,
          fileOptions: const FileOptions(
            contentType: 'image/png',
            upsert: true,
          ),
        );
  }

  Future<Uint8List?> _fetchWorkspaceEmblemImpl(String workspaceId) async {
    try {
      return await _client.storage
          .from('floor-plans')
          .download(SupabaseWorkspaceRepository.emblemPath(workspaceId));
    } on StorageException {
      // No object, or not readable by this member: the app renders as it
      // always did. Not a fault worth surfacing (#1289).
      return null;
    }
  }

  Future<void> _clearWorkspaceEmblemImpl(String workspaceId) async {
    await _client.storage
        .from('floor-plans')
        .remove([SupabaseWorkspaceRepository.emblemPath(workspaceId)]);
  }

  Future<Map<String, dynamic>> _setWorkspaceBrandingImpl(
    String workspaceId,
    Map<String, dynamic> delta,
  ) async {
    final dynamic out;
    try {
      out = await _client.rpc<dynamic>('set_workspace_branding', params: {
        'p_workspace_id': workspaceId,
        'p_branding': delta,
      });
    } on PostgrestException catch (e, st) {
      // 0378 — the letters-and-colour pair is unique across workspaces.
      if (e.code == '23505') {
        Error.throwWithStackTrace(const WorkspaceSymbolTaken(), st);
      }
      rethrow;
    }
    return Map<String, dynamic>.from(out as Map? ?? const <String, dynamic>{});
  }

  

  

  

  

  

  

  

  Future<String?> _fetchDefaultWorkspaceIdImpl() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('profiles')
        .select('default_workspace_id')
        .eq('id', userId)
        .maybeSingle();
    return row?['default_workspace_id'] as String?;
  }

  Future<void> _setDefaultWorkspaceIdImpl(String? workspaceId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('profiles')
        .update({'default_workspace_id': workspaceId}).eq('id', userId);
  }

  

  

  

  

  

  Future<Workspace> _saveWorkspaceSettingsImpl(
      String workspaceId, WorkspaceSettingsSave save) async {
    try {
      final result = await _client.rpc<dynamic>('save_workspace_settings', params: {
        'p_workspace_id': workspaceId,
        'p_expected_modified': save.expectedModifiedAt?.toUtc().toIso8601String(),
        'p_settings': save.toSettings(),
      });
      return _workspaceFromRow(Map<String, dynamic>.from(
          (result as Map)['workspace'] as Map));
    } on PostgrestException catch (e, st) {
      // trace-exempt: a conflict is rethrown typed with its stack; the screen traces and explains it.
      if (e.code == WorkspaceSettingsConflict.sqlState) {
        Error.throwWithStackTrace(const WorkspaceSettingsConflict(), st);
      }
      rethrow;
    }
  }

  Future<void> _setDeskOpacityImpl(String workspaceId, int opacity) async {
    await _updateWorkspaceRow(workspaceId, {'desk_opacity': opacity});
  }

  Future<void> _resetWorkspaceImpl(String workspaceId) async {
    // SECURITY DEFINER RPC (0039); the owner check + all deletes are atomic
    // server-side.
    await _client.rpc<dynamic>('reset_workspace', params: {
      'p_workspace_id': workspaceId,
    });
  }

  

  
}

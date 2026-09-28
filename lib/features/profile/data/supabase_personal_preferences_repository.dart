// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/personal_preferences.dart';

class SupabasePersonalPreferencesRepository implements PersonalPreferencesRepository {
  SupabasePersonalPreferencesRepository(this.client);
  final SupabaseClient client;

  @override
  Future<PersonalPreferences> read({String? workspaceId}) async {
    final data = await client.rpc<Map<String, dynamic>>('my_personal_preferences',
      params: {'p_workspace_id': workspaceId});
    return PersonalPreferences.fromJson(data);
  }

  @override
  Future<void> patch(Map<String, String?> values, {String? workspaceId}) =>
      client.rpc<void>('set_personal_preferences',
        params: {'p_patch': values, 'p_workspace_id': workspaceId,
          'p_expected_account': client.auth.currentUser?.id});
}

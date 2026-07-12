// SPDX-License-Identifier: MIT
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile.dart';
import '../domain/profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Profile?> fetchMyProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return Profile.fromDb(row);
  }

  @override
  Future<List<Profile>> fetchProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return const [];
    final rows =
        await _client.from('profiles').select().inFilter('id', userIds);
    return rows.map(Profile.fromDb).toList();
  }

  @override
  Future<void> updateWhatsapp(String whatsapp) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('cannot update the profile while signed out');
    }
    // Direct row update — profiles_update RLS (0002) restricts it to
    // self, and the 0028 column check re-validates the '+digits' shape.
    await _client
        .from('profiles')
        .update({'whatsapp': whatsapp}).eq('id', userId);
  }

  @override
  Future<void> touchLastSeen() async {
    await _client.rpc<dynamic>('touch_last_seen');
  }
}

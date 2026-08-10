// SPDX-License-Identifier: 0BSD
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile.dart';
import '../domain/profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  /// Storage object path of [userId]'s avatar in the private bucket (0038).
  static String _avatarPath(String userId) => '$userId/avatar';

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
  Future<void> updateWhatsappNotes(bool enabled) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('cannot update the profile while signed out');
    }
    await _client
        .from('profiles')
        .update({'whatsapp_notes': enabled}).eq('id', userId);
  }

  @override
  Future<void> updateStatusText(String statusText) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('cannot update the profile while signed out');
    }
    // Direct row update — profiles_update RLS (0002) restricts it to
    // self, and the 0029 column check re-validates the 40-char cap.
    // Defensive re-normalization: the cap must hold even for a caller
    // that skipped normalizeStatusText.
    await _client
        .from('profiles')
        .update({'status_text': normalizeStatusText(statusText)})
        .eq('id', userId);
  }

  @override
  Future<void> updateAddress(String address) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('cannot update the profile while signed out');
    }
    // Self-only via profiles_update RLS (0002); 0060 caps at 400 chars.
    await _client
        .from('profiles')
        .update({'address': address.trim()}).eq('id', userId);
  }

  @override
  Future<void> updateTaxIdentity({
    required String countryCode,
    required String vatId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('cannot update the profile while signed out');
    }
    // Self-only via profiles_update RLS; the 0069 column checks enforce
    // the two-letter shape and the length.
    await _client.from('profiles').update({
      'country_code': countryCode.trim().toUpperCase(),
      'vat_id': vatId.trim(),
    }).eq('id', userId);
  }

  @override
  Future<void> setPreferredLocale(String locale) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('not signed in');
    await _client
        .from('profiles')
        .update({'preferred_locale': locale}).eq('id', userId);
  }

  @override
  Future<void> touchLastSeen() async {
    await _client.rpc<dynamic>('touch_last_seen');
  }

  @override
  Future<void> setAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('cannot update the profile while signed out');
    }
    final path = _avatarPath(userId);
    // Self-only storage RLS (0038); upsert overwrites a previous photo.
    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    await _client
        .from('profiles')
        .update({'avatar_path': path}).eq('id', userId);
  }

  @override
  Future<void> clearAvatar() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('cannot update the profile while signed out');
    }
    await _client.storage.from('avatars').remove([_avatarPath(userId)]);
    await _client
        .from('profiles')
        .update({'avatar_path': null}).eq('id', userId);
  }

  @override
  Future<Uint8List?> fetchAvatarBytes(String userId) async {
    try {
      return await _client.storage.from('avatars').download(
            _avatarPath(userId),
          );
    } on StorageException {
      // No object (never uploaded) or not readable — the initial avatar
      // shows instead; not an error worth surfacing.
      return null;
    }
  }
}

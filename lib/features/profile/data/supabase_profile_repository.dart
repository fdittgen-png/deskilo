// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/i18n/format_prefs.dart';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile.dart';
import '../domain/profile_projection.dart';
import '../domain/personal_info.dart';
import '../domain/profile_repository.dart';
import '../domain/privacy_notice.dart';
import '../domain/rights_request.dart';

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
  Future<List<Profile>> fetchProfiles(
    String workspaceId,
    List<String> userIds,
  ) async {
    // An empty id (a managed member, #962) is not a uuid: PostgREST
    // answers 22P02 for the whole request, so it is dropped here too.
    final ids = [for (final id in userIds) if (id.isNotEmpty) id];
    if (ids.isEmpty || workspaceId.isEmpty) return const [];
    // #1833 — never `select *` on another person's row: the projection
    // carries only the groups the server grants this caller.
    final rows = await _client.rpc<List<dynamic>>(
      'member_profiles',
      params: {'p_workspace_id': workspaceId, 'p_user_ids': ids},
    );
    return [
      for (final row in rows)
        profileFromProjection((row as Map).cast<String, dynamic>()),
    ];
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
        .update({'whatsapp': whatsapp})
        .eq('id', userId);
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

  @override
  Future<void> updatePersonalInfo(PersonalInfo info) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('cannot update the profile while signed out');
    }
    // Self-only via profiles_update RLS; the 0152 column checks bound
    // every field. Stored normalized, so what prints is what was typed
    // minus the whitespace and with the country in capitals.
    await _client
        .from('profiles')
        .update(info.normalized().toDb())
        .eq('id', userId);
  }

  @override
  Future<void> updateInvoiceIdentity({
    required String address,
    required String countryCode,
    required String vatId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('cannot update the profile while signed out');
    }
    // Self-only via profiles_update RLS (0002); 0060 caps the address at
    // 400 chars and the 0069 column checks enforce the country's
    // two-letter shape and the VAT id's length.
    //
    // ONE update: these three are one block on the invoice, and as two
    // calls a failure on the second billed the member at their new
    // address under their old VAT identity (#1532).
    await _client
        .from('profiles')
        .update({
          'address': address.trim(),
          'country_code': countryCode.trim().toUpperCase(),
          'vat_id': vatId.trim(),
        })
        .eq('id', userId);
  }

  @override
  Future<void> setPreferredLocale(String locale) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('not signed in');
    await _client
        .from('profiles')
        .update({'preferred_locale': locale})
        .eq('id', userId);
  }

  @override
  Future<void> setFormatPrefs(FormatPrefs prefs) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('not signed in');
    await _client.from('profiles').update(prefs.toDb()).eq('id', userId);
  }

  @override
  Future<void> acceptPrivacyPolicy(String version) => _client.rpc<void>(
    'accept_privacy_policy',
    params: {'p_version': version},
  );

  @override
  Future<PrivacyNotices> fetchPrivacyNotices(String? workspaceId) async {
    final row = await _client.rpc<dynamic>(
      'current_privacy_notice',
      params: {'p_workspace_id': workspaceId},
    );
    return row is Map
        ? PrivacyNotices.fromJson(
            Map<String, dynamic>.from(row),
            workspaceId: workspaceId,
          )
        : PrivacyNotices.none;
  }

  @override
  Future<RightsRequest> submitRightsRequest({
    required String workspaceId,
    required String kind,
    required String details,
    required String clientRequestId,
  }) async {
    final row = await _client.rpc<dynamic>('submit_rights_request', params: {
      'p_workspace_id': workspaceId,
      'p_kind': kind,
      'p_details': details,
      'p_client_request_id': clientRequestId,
    });
    return RightsRequest.fromJson(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<List<RightsRequest>> fetchMyRightsRequests() async {
    final rows = await _client.rpc<dynamic>('my_rights_requests');
    return [
      for (final row in (rows as List? ?? const []))
        RightsRequest.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  @override
  Future<ErasurePreview> previewMyErasure(String workspaceId) async {
    final row = await _client.rpc<dynamic>('preview_my_erasure',
        params: {'p_workspace_id': workspaceId});
    return row is Map
        ? ErasurePreview.fromJson(Map<String, dynamic>.from(row))
        : const ErasurePreview();
  }

  @override
  Future<void> acknowledgeWorkspaceNotice(String workspaceId, String version) =>
      _client.rpc<void>('acknowledge_workspace_notice',
          params: {'p_workspace_id': workspaceId, 'p_version': version});

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
    await _client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    await _client
        .from('profiles')
        .update({'avatar_path': path})
        .eq('id', userId);
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
        .update({'avatar_path': null})
        .eq('id', userId);
  }

  @override
  Future<Uint8List?> fetchAvatarBytes(String userId) async {
    try {
      return await _client.storage
          .from('avatars')
          .download(_avatarPath(userId));
    } on StorageException {
      // No object (never uploaded) or not readable — the initial avatar
      // shows instead; not an error worth surfacing.
      return null;
    }
  }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/me_repository.dart';
import '../domain/personal_export.dart';
import '../domain/personal_workspace_refs.dart';
import '../domain/public_person.dart';
import '../domain/visibility.dart';
import 'visibility_rpc.dart';

/// #1823 — [MeRepository] over this server's client.
class SupabaseMeRepository implements MeRepository {
  const SupabaseMeRepository(this._client);

  final SupabaseClient _client;

  Map<String, dynamic> _object(Object? raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

  @override
  Future<PersonalWorkspaceRefs> myWorkspaceRefs() async =>
      PersonalWorkspaceRefs.fromJson(
          await _client.rpc<Object?>('my_personal_workspace_refs_v1'));

  @override
  Future<PersonalExport> exportMyPersonalData() async {
    final Object? raw;
    try {
      raw = await _client.rpc<Object?>('export_my_personal_data_v1');
    } on PostgrestException catch (e, st) {
      // trace-exempt: rethrown typed; the hub names the refusal.
      final failure = personalExportRefusalOf(e);
      if (failure == null) rethrow;
      Error.throwWithStackTrace(
          PersonalExportRefused(failure, detail: e.message), st);
    }
    return PersonalExport.decode(raw);
  }

  @override
  Future<MyVisibility> myVisibility() => readMyNetworkVisibility(_client);

  @override
  Future<void> setVisibility(
    VisibilityField field,
    FieldAudience audience,
  ) =>
      writeVisibility(_client, field, audience);

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
  Future<void> setPublicProfile({required bool publish}) => _client.rpc<void>(
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
}

/// The SQLSTATEs the personal export raises on purpose: no such reader on
/// this home, or a session it refuses (0564's native guard raises P0001
/// with its own words). Anything else is not a refusal.
@visibleForTesting
PersonalExportFailure? personalExportRefusalOf(PostgrestException e) =>
    switch (e.code) {
      'PGRST202' || '42883' => PersonalExportFailure.unsupported,
      '42501' => PersonalExportFailure.forbidden,
      'P0001'
          when e.message.contains('identity_session_refused') ||
              e.message.contains('not authenticated') ||
              e.message.contains('managed in the Deskilo app') =>
        PersonalExportFailure.forbidden,
      _ => null,
    };

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4006 — the reader's organisations and the owners' commands on them, over
// the server's read and commands (#4004).
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/trace/trace_logger.dart';
import '../domain/organisation.dart';

class SupabaseOrganisationRepository implements OrganisationRepository {
  const SupabaseOrganisationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Organisation>> myOrganisations() async {
    final rows = await _client.rpc<Object?>('my_organisations_v1');
    return [
      if (rows is List)
        for (final row in rows) Organisation.fromJson(row),
    ];
  }

  @override
  Future<OrganisationRefusal?> create(String headWorkspaceId, String name) =>
      _command('create_organisation', {
        'p_head': headWorkspaceId,
        'p_name': name,
      });

  @override
  Future<OrganisationRefusal?> rename(String organisationId, String name) =>
      _command('rename_organisation', {
        'p_organisation': organisationId,
        'p_name': name,
      });

  @override
  Future<OrganisationRefusal?> add(String organisationId, String workspaceId) =>
      _command('add_business_to_organisation', {
        'p_organisation': organisationId,
        'p_business': workspaceId,
      });

  @override
  Future<OrganisationRefusal?> remove(String workspaceId) => _command(
    'remove_business_from_organisation',
    {'p_business': workspaceId},
  );

  @override
  Future<OrganisationRefusal?> setHead(
    String organisationId,
    String headWorkspaceId,
  ) => _command('set_organisation_head', {
    'p_organisation': organisationId,
    'p_head': headWorkspaceId,
  });

  Future<OrganisationRefusal?> _command(
    String name,
    Map<String, Object?> params,
  ) async {
    try {
      await _client.rpc<Object?>(name, params: params);
      return null;
    } on PostgrestException catch (e, st) {
      if (!const {'42501', '22023', '55000'}.contains(e.code)) rethrow;
      TraceLogger.instance.warn(
        'workspace',
        'organisation command refused',
        error: e,
        stackTrace: st,
      );
      return refusalOf(e.code, e.message);
    }
  }

  /// The refusal the server's [code] and [message] say.
  static OrganisationRefusal refusalOf(String? code, String message) =>
      switch ((code, message)) {
        ('42501', _) => OrganisationRefusal.notOwner,
        ('55000', _) => OrganisationRefusal.featureOff,
        (_, 'a development twin is never the head') =>
          OrganisationRefusal.twinNeverHead,
        (_, 'the new head is not a house of this organisation') =>
          OrganisationRefusal.notAHouse,
        (_, 'an organisation needs a name') => OrganisationRefusal.noName,
        (_, 'this business is already in an organisation') =>
          OrganisationRefusal.alreadyInOne,
        (_, 'this business is in no organisation') =>
          OrganisationRefusal.inNone,
        (_, 'the head leaves last') => OrganisationRefusal.headLeavesLast,
        _ => OrganisationRefusal.other,
      };
}

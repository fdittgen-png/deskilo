// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4006 — the reader's organisations and the owners' commands on them, over
// the server's read and commands (#4004).
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/trace/trace_logger.dart';
import '../domain/organisation.dart';
import '../domain/organisation_overview.dart';

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
  Future<OrganisationOverview> overview(
    String organisationId, {
    required String fromMonth,
    required String toMonth,
  }) async => OrganisationOverview.fromJson(
    await _client.rpc<Object?>(
      'organisation_overview_v1',
      params: {
        'p_organisation': organisationId,
        'p_from': fromMonth,
        'p_to': toMonth,
      },
    ),
  );

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

  @override
  Future<({String? workspaceId, OrganisationRefusal? refused})> createHouse(
    HouseRequest request,
  ) async {
    try {
      final answer = await _client.rpc<Object?>(
        'create_organisation_house_once',
        params: {
          'p_organisation': request.organisationId,
          'p_name': request.name,
          'p_country': request.country,
          'p_currency': request.currency,
          'p_timezone': request.timezone,
          'p_language': request.language,
          'p_client_request_id': request.requestId,
        },
      );
      final id = JsonReader.of(answer, context: 'house').string('workspace_id');
      return (workspaceId: id, refused: null);
    } on PostgrestException catch (e, st) {
      if (!const {'42501', '22023', '55000'}.contains(e.code)) rethrow;
      TraceLogger.instance.warn(
        'workspace',
        'house refused',
        error: e,
        stackTrace: st,
      );
      return (workspaceId: null, refused: refusalOf(e.code, e.message));
    }
  }

  @override
  Future<HouseBirth?> houseBirth(String workspaceId) async {
    final row = await _client
        .from('organisation_houses')
        .select()
        .eq('workspace_id', workspaceId)
        .maybeSingle();
    return row == null ? null : HouseBirth.fromJson(row);
  }

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
        (_, 'the language is one of en, fr, de, es, it') =>
          OrganisationRefusal.language,
        (_, 'this request id already created another business') =>
          OrganisationRefusal.requestUsed,
        _ => OrganisationRefusal.other,
      };
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2597 -- sites and a member's home site, as one mixin composed into
// `SupabaseWorkspaceRepository` (the part-file bodies and their `_xxxImpl`
// forwarders are gone).

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/site.dart';
import '../domain/site_repository.dart';

mixin SupabaseSites implements SiteRepository {
  /// The client of the class this is mixed into.
  SupabaseClient get client;

  @override
  Future<List<Site>> fetchSites(String workspaceId) async {
    final rows = await client
        .from('sites')
        .select()
        .eq('workspace_id', workspaceId)
        .order('is_default', ascending: false)
        .order('sort_order')
        .order('name');
    return rows.map((r) => Site.fromRow(Map<String, dynamic>.from(r))).toList();
  }

  @override
  Future<String> upsertSite(
    String workspaceId,
    Site site, {
    bool isNew = false,
  }) async {
    final r = await client.rpc<dynamic>(
      'upsert_site',
      params: {
        'p_workspace_id': workspaceId,
        'p_id': isNew ? null : site.id,
        'p_name': site.name,
        'p_street': site.street,
        'p_postal_code': site.postalCode,
        'p_city': site.city,
        'p_country_code': site.countryCode,
        'p_legal_id': site.legalId,
        'p_sort_order': site.sortOrder,
        'p_vat_id': site.vatId,
        'p_tax_exemption_reason': site.taxExemptionReason,
      },
    );
    return r as String;
  }

  @override
  Future<void> deleteSite(String siteId) async {
    await client.rpc<dynamic>('delete_site', params: {'p_site_id': siteId});
  }

  @override
  Future<void> setMemberHomeSite(String memberId, String? siteId) async {
    await client.rpc<dynamic>(
      'set_member_home_site',
      params: {'p_member_id': memberId, 'p_site_id': siteId},
    );
  }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/paged_fetch.dart';
import '../../../core/data/system_columns.dart';
import '../../../core/vat/supply_class.dart';
import '../domain/commercial_terms_repository.dart';
import '../domain/fee_band.dart';
import '../domain/package.dart';
import '../domain/price_negotiation.dart';
import '../domain/service_item.dart';
import '../domain/subscription_levels.dart';

/// #2591 C4 — the commercial terms, with their own client. The bodies are
/// the ones that lived in the money repository's part files.
class SupabaseCommercialTermsRepository implements CommercialTermsRepository {
  SupabaseCommercialTermsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<FeeBand>> fetchFeeBands(String workspaceId) async {
    final rows = await _client
        .from('fee_bands')
        .select()
        .eq('workspace_id', workspaceId)
        .order('from_pct', ascending: true);
    return rows
        .map(
          (row) => FeeBand(
            system: SystemColumns.fromRow(row),
            id: row['id'] as String,
            workspaceId: row['workspace_id'] as String,
            fromPct: row['from_pct'] as int,
            toPct: row['to_pct'] as int,
            feeCents: row['fee_cents'] as int,
            overageFeeCents: row['overage_fee_cents'] as int,
          ),
        )
        .toList();
  }

  @override
  Future<void> replaceFeeBands(String workspaceId, List<FeeBand> bands) async {
    await _client.rpc<dynamic>(
      'replace_fee_bands',
      params: {
        'p_workspace_id': workspaceId,
        'p_bands': [
          for (final band in bands)
            {
              'from_pct': band.fromPct,
              'to_pct': band.toPct,
              'fee_cents': band.feeCents,
              'overage_fee_cents': band.overageFeeCents,
            },
        ],
      },
    );
  }

  @override
  Future<SubscriptionLevels> fetchSubscriptionLevels(String workspaceId) async {
    final row = await _client
        .from('workspaces')
        .select('subscription_levels')
        .eq('id', workspaceId)
        .single();
    return SubscriptionLevels.fromDb(
      row['subscription_levels'] as Map<String, dynamic>? ?? const {},
    );
  }

  @override
  Future<void> setSubscriptionLevels(
    String workspaceId,
    SubscriptionLevels levels,
  ) async {
    await _client
        .from('workspaces')
        .update({'subscription_levels': levels.toDb()})
        .eq('id', workspaceId);
  }

  @override
  Future<List<ServiceItem>> fetchServices(
    String workspaceId, {
    bool includeInactive = false,
  }) async {
    // #1310 S2 — paged: the export asks for the catalogue including
    // retired entries, which is the longest form of this list.
    final rows = await fetchAllPages(
      table: 'services',
      build: () {
        var query = _client
            .from('services')
            .select()
            .eq('workspace_id', workspaceId);
        if (!includeInactive) query = query.eq('active', true);
        return query
            .order('name', ascending: true)
            .order('id', ascending: true);
      },
    );
    return rows.map(_serviceFromRow).toList();
  }

  @override
  Future<ServiceItem> createService(
    String workspaceId, {
    required String name,
    required int priceCents,
    String? vatRateId,
    SupplyClass supplyClass = SupplyClass.property,
  }) async {
    final row = await _client
        .from('services')
        .insert({
          'supply_class': supplyClass.wire,
          'workspace_id': workspaceId,
          'name': name,
          'price_cents': priceCents,
          // '' means "the workspace default", which the column stores as
          // NULL — the resolution lives in one place, the server.
          'vat_rate_id': (vatRateId ?? '').isEmpty ? null : vatRateId,
        })
        .select()
        .single();
    return _serviceFromRow(row);
  }

  @override
  Future<ServiceItem> updateService(
    String serviceId, {
    String? name,
    int? priceCents,
    bool? active,
    String? vatRateId,
    SupplyClass? supplyClass,
  }) async {
    final row = await _client
        .from('services')
        .update({
          'supply_class': ?supplyClass?.wire,
          'name': ?name,
          'price_cents': ?priceCents,
          'active': ?active,
          if (vatRateId != null)
            'vat_rate_id': vatRateId.isEmpty ? null : vatRateId,
        })
        .eq('id', serviceId)
        .select()
        .single();
    return _serviceFromRow(row);
  }

  @override
  Future<List<Package>> fetchPackages(
    String workspaceId, {
    bool includeInactive = false,
  }) async {
    var query = _client
        .from('packages')
        .select()
        .eq('workspace_id', workspaceId);
    if (!includeInactive) query = query.eq('active', true);
    final rows = await query.order('days', ascending: true);
    return rows.map(Package.fromRow).toList();
  }

  @override
  Future<Package> createPackage(
    String workspaceId, {
    required String name,
    required int days,
    required int priceCents,
    String? vatRateId,
  }) async {
    final row = await _client
        .from('packages')
        .insert({
          'workspace_id': workspaceId,
          'name': name,
          'days': days,
          'price_cents': priceCents,
          'vat_rate_id': (vatRateId ?? '').isEmpty ? null : vatRateId,
        })
        .select()
        .single();
    return Package.fromRow(row);
  }

  @override
  Future<Package> updatePackage(
    String packageId, {
    String? name,
    int? days,
    int? priceCents,
    bool? active,
    String? vatRateId,
  }) async {
    final row = await _client
        .from('packages')
        .update({
          'name': ?name,
          'days': ?days,
          'price_cents': ?priceCents,
          'active': ?active,
          if (vatRateId != null)
            'vat_rate_id': vatRateId.isEmpty ? null : vatRateId,
        })
        .eq('id', packageId)
        .select()
        .single();
    return Package.fromRow(row);
  }

  @override
  Future<PriceNegotiation> fetchPriceNegotiation(String memberId) async =>
      PriceNegotiation.fromJson(
        await _client.rpc<dynamic>(
          'member_price_negotiation',
          params: {'p_member_id': memberId},
        ) as Map<String, dynamic>,
      );

  @override
  Future<void> proposePriceNegotiation({
    required String memberId,
    int? feeCents,
    int? overageFeeCents,
    double? discountPercent,
    String note = '',
    DateTime? validFrom,
    int? subscriptionPct,
    Map<String, Map<String, int>> items = const {},
  }) => _client.rpc<void>(
    'propose_price_negotiation',
    params: {
      'p_member_id': memberId,
      'p_fee_cents': feeCents,
      'p_overage_fee_cents': overageFeeCents,
      'p_discount_percent': discountPercent,
      'p_note': note,
      'p_valid_from': validFrom?.toIso8601String().substring(0, 10),
      'p_subscription_pct': subscriptionPct,
      'p_items': items,
    },
  );

  ServiceItem _serviceFromRow(Map<String, dynamic> row) => ServiceItem(
    system: SystemColumns.fromRow(row),
    id: row['id'] as String,
    workspaceId: row['workspace_id'] as String,
    name: row['name'] as String,
    priceCents: row['price_cents'] as int,
    active: row['active'] as bool,
    vatRateId: row['vat_rate_id'] as String? ?? '',
    stock: row['stock'] as int?,
    supplyClass: SupplyClass.fromWire(row['supply_class'] as String?),
  );
}

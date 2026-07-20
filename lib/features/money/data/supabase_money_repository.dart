// SPDX-License-Identifier: MIT
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/fee_band.dart';
import '../domain/ledger_entry.dart';
import '../domain/money_repository.dart';
import '../domain/package.dart';
import '../domain/payment_method.dart';
import '../domain/service_item.dart';
import '../domain/statement.dart';
import '../domain/subscription_levels.dart';

class SupabaseMoneyRepository implements MoneyRepository {
  SupabaseMoneyRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Statement> fetchStatement(String memberId, String period) async {
    final result = await _client.rpc<dynamic>('member_statement', params: {
      'p_member_id': memberId,
      'p_period': period,
    }) as Map<String, dynamic>;
    // Parsing lives in the domain (Statement.fromRpc) so the #170
    // supplement-field tolerance is pure-Dart testable.
    return Statement.fromRpc(result);
  }

  @override
  Future<List<LedgerEntry>> fetchLedger(String memberId) async {
    final rows = await _client
        .from('ledger_entries')
        .select()
        .eq('member_id', memberId)
        .order('created_at', ascending: false);
    return rows
        .map(
          (row) => LedgerEntry(
            id: row['id'] as String,
            memberId: row['member_id'] as String,
            kind: LedgerKind.values.byName(row['kind'] as String),
            category:
                LedgerCategory.values.byName(row['category'] as String),
            amountCents: row['amount_cents'] as int,
            description: row['description'] as String,
            period: row['period'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  @override
  Future<String> recordPayment({
    required String workspaceId,
    required String memberId,
    required int amountCents,
    String note = '',
    PaymentMethod? method,
  }) async {
    final result = await _client.rpc<dynamic>('record_payment', params: {
      'p_workspace_id': workspaceId,
      'p_member_id': memberId,
      'p_amount_cents': amountCents,
      'p_note': note,
      'p_method': method?.wireName ?? '',
    });
    return result as String;
  }

  @override
  Future<void> recordServiceCharge({
    required String workspaceId,
    required String subjectMemberId,
    required String serviceId,
    required int quantity,
    String? period,
  }) async {
    await _client.rpc<dynamic>('record_service_charge', params: {
      'p_workspace_id': workspaceId,
      'p_subject_member_id': subjectMemberId,
      'p_service_id': serviceId,
      'p_quantity': quantity,
      'p_period': ?period,
    });
  }

  @override
  Future<String> submitExpense({
    required String workspaceId,
    required int amountCents,
    required String category,
    String description = '',
  }) async {
    final result = await _client.rpc<dynamic>('submit_expense', params: {
      'p_workspace_id': workspaceId,
      'p_amount_cents': amountCents,
      'p_category': category,
      'p_description': description,
    });
    return result as String;
  }

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
  Future<void> replaceFeeBands(
    String workspaceId,
    List<FeeBand> bands,
  ) async {
    await _client.rpc<dynamic>('replace_fee_bands', params: {
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
    });
  }

  @override
  Future<SubscriptionLevels> fetchSubscriptionLevels(
    String workspaceId,
  ) async {
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
        .update({'subscription_levels': levels.toDb()}).eq(
      'id',
      workspaceId,
    );
  }

  ServiceItem _serviceFromRow(Map<String, dynamic> row) => ServiceItem(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        name: row['name'] as String,
        priceCents: row['price_cents'] as int,
        active: row['active'] as bool,
      );

  @override
  Future<List<ServiceItem>> fetchServices(
    String workspaceId, {
    bool includeInactive = false,
  }) async {
    var query =
        _client.from('services').select().eq('workspace_id', workspaceId);
    if (!includeInactive) query = query.eq('active', true);
    final rows = await query.order('name', ascending: true);
    return rows.map(_serviceFromRow).toList();
  }

  @override
  Future<ServiceItem> createService(
    String workspaceId, {
    required String name,
    required int priceCents,
  }) async {
    final row = await _client
        .from('services')
        .insert({
          'workspace_id': workspaceId,
          'name': name,
          'price_cents': priceCents,
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
  }) async {
    final row = await _client
        .from('services')
        .update({
          'name': ?name,
          'price_cents': ?priceCents,
          'active': ?active,
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
    var query =
        _client.from('packages').select().eq('workspace_id', workspaceId);
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
  }) async {
    final row = await _client
        .from('packages')
        .insert({
          'workspace_id': workspaceId,
          'name': name,
          'days': days,
          'price_cents': priceCents,
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
  }) async {
    final row = await _client
        .from('packages')
        .update({
          'name': ?name,
          'days': ?days,
          'price_cents': ?priceCents,
          'active': ?active,
        })
        .eq('id', packageId)
        .select()
        .single();
    return Package.fromRow(row);
  }

  @override
  Future<String> buyPackage(String workspaceId, String packageId) async {
    final result = await _client.rpc<dynamic>('buy_package', params: {
      'p_workspace_id': workspaceId,
      'p_package_id': packageId,
    });
    return result as String;
  }
}

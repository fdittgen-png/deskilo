// SPDX-License-Identifier: MIT
import 'package:deskilo/features/money/domain/fee_band.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/money_repository.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/money/domain/statement.dart';
import 'package:deskilo/features/money/domain/subscription_levels.dart';

/// In-memory [MoneyRepository]; recorded payments are captured for
/// assertions (they only become ledger credits after confirmation).
class FakeMoneyRepository implements MoneyRepository {
  Statement statement = const Statement(
    period: '2026-07',
    subscriptionPct: 50,
    feeCents: 15000,
    includedHalfDays: 22,
    openDays: 22,
    usedHalfDays: 24,
    extraHalfDays: 2,
    overageCents: 1600,
    creditsCents: 15000,
    balanceCents: -1600,
  );

  final ledger = <LedgerEntry>[];
  final recordedPayments = <({int amountCents, String note})>[];

  @override
  Future<Statement> fetchStatement(String memberId, String period) async =>
      statement;

  @override
  Future<List<LedgerEntry>> fetchLedger(String memberId) async =>
      List.of(ledger);

  @override
  Future<String> recordPayment({
    required String workspaceId,
    required String memberId,
    required int amountCents,
    String note = '',
  }) async {
    recordedPayments.add((amountCents: amountCents, note: note));
    return 'evt-payment-${recordedPayments.length}';
  }

  /// Mirrors the migration's default seed: (0,25] Flex-like, (25,50]
  /// Half-like, (50,100] Full-like (#128).
  final feeBands = <FeeBand>[
    const FeeBand(
      id: 'band-1',
      workspaceId: 'ws-1',
      fromPct: 0,
      toPct: 25,
      feeCents: 0,
      overageFeeCents: 1500,
    ),
    const FeeBand(
      id: 'band-2',
      workspaceId: 'ws-1',
      fromPct: 25,
      toPct: 50,
      feeCents: 15000,
      overageFeeCents: 800,
    ),
    const FeeBand(
      id: 'band-3',
      workspaceId: 'ws-1',
      fromPct: 50,
      toPct: 100,
      feeCents: 25000,
      overageFeeCents: 0,
    ),
  ];

  @override
  Future<List<FeeBand>> fetchFeeBands(String workspaceId) async =>
      List.of(feeBands)..sort((a, b) => a.fromPct.compareTo(b.fromPct));

  @override
  Future<void> replaceFeeBands(
    String workspaceId,
    List<FeeBand> bands,
  ) async {
    // Same contiguity contract as the replace_fee_bands RPC.
    var expected = 0;
    for (final band in bands.toList()
      ..sort((a, b) => a.fromPct.compareTo(b.fromPct))) {
      if (band.fromPct != expected) throw StateError('bands not contiguous');
      expected = band.toPct;
    }
    if (expected != 100) throw StateError('bands must cover up to 100');
    feeBands
      ..clear()
      ..addAll([
        for (final (i, band) in bands.indexed)
          band.copyWith(id: 'band-${i + 1}', workspaceId: workspaceId),
      ]);
  }

  SubscriptionLevels subscriptionLevels = const SubscriptionLevels();

  @override
  Future<SubscriptionLevels> fetchSubscriptionLevels(
    String workspaceId,
  ) async =>
      subscriptionLevels;

  @override
  Future<void> setSubscriptionLevels(
    String workspaceId,
    SubscriptionLevels levels,
  ) async {
    subscriptionLevels = levels;
  }

  final services = <ServiceItem>[
    const ServiceItem(
      id: 'service-coffee',
      workspaceId: 'ws-1',
      name: 'Coffee',
      priceCents: 150,
      active: true,
    ),
    const ServiceItem(
      id: 'service-locker',
      workspaceId: 'ws-1',
      name: 'Locker',
      priceCents: 500,
      active: false,
    ),
    const ServiceItem(
      id: 'service-printing',
      workspaceId: 'ws-1',
      name: 'Printing',
      priceCents: 20,
      active: true,
    ),
  ];

  @override
  Future<List<ServiceItem>> fetchServices(
    String workspaceId, {
    bool includeInactive = false,
  }) async =>
      services.where((s) => includeInactive || s.active).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  @override
  Future<ServiceItem> createService(
    String workspaceId, {
    required String name,
    required int priceCents,
  }) async {
    final service = ServiceItem(
      id: 'service-${services.length + 1}',
      workspaceId: workspaceId,
      name: name,
      priceCents: priceCents,
      active: true,
    );
    services.add(service);
    return service;
  }

  @override
  Future<ServiceItem> updateService(
    String serviceId, {
    String? name,
    int? priceCents,
    bool? active,
  }) async {
    final i = services.indexWhere((s) => s.id == serviceId);
    if (i < 0) throw StateError('unknown service');
    final updated = services[i].copyWith(
      name: name ?? services[i].name,
      priceCents: priceCents ?? services[i].priceCents,
      active: active ?? services[i].active,
    );
    services[i] = updated;
    return updated;
  }

  final submittedExpenses =
      <({int amountCents, String category, String description})>[];

  @override
  Future<String> submitExpense({
    required String workspaceId,
    required int amountCents,
    required String category,
    String description = '',
  }) async {
    submittedExpenses.add(
      (
        amountCents: amountCents,
        category: category,
        description: description,
      ),
    );
    return 'evt-expense-${submittedExpenses.length}';
  }
}

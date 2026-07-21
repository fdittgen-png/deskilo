// SPDX-License-Identifier: 0BSD
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/fee_band.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/money_repository.dart';
import 'package:deskilo/features/money/domain/package.dart';
import 'package:deskilo/features/money/domain/payment_method.dart';
import 'package:deskilo/features/money/domain/payment_provider.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/money/domain/statement.dart';
import 'package:deskilo/features/money/domain/subscription_levels.dart';

import 'fake_event_repository.dart';

/// In-memory [MoneyRepository]; recorded payments are captured for
/// assertions (they only become ledger credits after confirmation).
class FakeMoneyRepository implements MoneyRepository {
  FakeMoneyRepository({FakeEventRepository? events}) : _events = events;

  /// When wired, [recordServiceCharge] also files the pending
  /// service_charge event the real RPC creates (#134), so tests can drive
  /// the record → validate → bill flow through both fakes.
  final FakeEventRepository? _events;

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

  /// Per-period statements (#132); unseeded periods fall back to
  /// [statement] re-labelled with the requested period.
  final statements = <String, Statement>{};

  /// Every period the screen asked for, in order — lets tests assert the
  /// period chevrons change the query (#132).
  final fetchedPeriods = <String>[];

  final ledger = <LedgerEntry>[];
  final recordedPayments =
      <({int amountCents, String note, PaymentMethod? method})>[];

  @override
  Future<Statement> fetchStatement(String memberId, String period) async {
    fetchedPeriods.add(period);
    return statements[period] ?? statement.copyWith(period: period);
  }

  @override
  Future<List<LedgerEntry>> fetchLedger(String memberId) async =>
      List.of(ledger);

  @override
  Future<String> recordPayment({
    required String workspaceId,
    required String memberId,
    required int amountCents,
    String note = '',
    PaymentMethod? method,
  }) async {
    recordedPayments
        .add((amountCents: amountCents, note: note, method: method));
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

  /// Captured like [recordedPayments]: the real RPC only creates a pending
  /// event — nothing hits [ledger] until confirmation.
  final recordedServiceCharges = <({
    String workspaceId,
    String subjectMemberId,
    String serviceId,
    int quantity,
    String? period,
  })>[];

  @override
  Future<void> recordServiceCharge({
    required String workspaceId,
    required String subjectMemberId,
    required String serviceId,
    required int quantity,
    String? period,
  }) async {
    final service = services.firstWhere(
      (s) => s.id == serviceId,
      orElse: () => throw StateError('unknown service'),
    );
    if (!service.active) throw StateError('service is inactive');
    if (quantity < 1 || quantity > 999) {
      throw StateError('quantity must be between 1 and 999');
    }
    recordedServiceCharges.add(
      (
        workspaceId: workspaceId,
        subjectMemberId: subjectMemberId,
        serviceId: serviceId,
        quantity: quantity,
        period: period,
      ),
    );
    // Mirror the record_service_charge RPC: it only files a PENDING
    // service_charge event — the ledger charge appears on confirmation.
    final events = _events;
    if (events != null) {
      final now = DateTime.now();
      events.events.add(
        WorkspaceEvent(
          id: 'evt-service-${recordedServiceCharges.length}',
          workspaceId: workspaceId,
          type: EventType.serviceCharge,
          action: EventAction.submitted,
          // The signed-in viewer records the charge, exactly like the RPC
          // stamps auth.uid()'s member as the actor.
          actorMemberId: events.respondingMemberId,
          subjectMemberId: subjectMemberId,
          payload: {
            'service_id': serviceId,
            'name': service.name,
            'price_cents': service.priceCents,
            'quantity': quantity,
            'amount_cents': service.priceCents * quantity,
            'period': period ??
                '${now.year}-${now.month.toString().padLeft(2, '0')}',
          },
          status: EventStatus.pending,
          createdAt: now,
        ),
      );
    }
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

  /// Owner-defined packages; seeded with one 5-day pack by default.
  final packages = <Package>[
    const Package(
      id: 'package-5',
      workspaceId: 'ws-1',
      name: '5-day pack',
      days: 5,
      priceCents: 4000,
    ),
  ];

  @override
  Future<List<Package>> fetchPackages(
    String workspaceId, {
    bool includeInactive = false,
  }) async =>
      packages.where((p) => includeInactive || p.active).toList()
        ..sort((a, b) => a.days.compareTo(b.days));

  @override
  Future<Package> createPackage(
    String workspaceId, {
    required String name,
    required int days,
    required int priceCents,
  }) async {
    final package = Package(
      id: 'package-${packages.length + 1}',
      workspaceId: workspaceId,
      name: name,
      days: days,
      priceCents: priceCents,
    );
    packages.add(package);
    return package;
  }

  @override
  Future<Package> updatePackage(
    String packageId, {
    String? name,
    int? days,
    int? priceCents,
    bool? active,
  }) async {
    final i = packages.indexWhere((p) => p.id == packageId);
    if (i < 0) throw StateError('unknown package');
    final updated = packages[i].copyWith(
      name: name ?? packages[i].name,
      days: days ?? packages[i].days,
      priceCents: priceCents ?? packages[i].priceCents,
      active: active ?? packages[i].active,
    );
    packages[i] = updated;
    return updated;
  }

  /// (workspaceId, packageId) of buy_package calls.
  final boughtPackages = <(String, String)>[];

  @override
  Future<String> buyPackage(String workspaceId, String packageId) async {
    boughtPackages.add((workspaceId, packageId));
    return 'ext-${boughtPackages.length}';
  }

  /// Providers the fake deployment offers; empty models "not configured".
  List<PaymentProvider> paymentProviders = [PaymentProvider.paypal];

  /// Per-provider missing env vars reported by the config probe.
  Map<String, List<String>> paymentMissing = const {};

  /// (provider, amountCents) of createPaymentOrder calls.
  final paymentOrders = <(PaymentProvider, int)>[];

  /// Approval URL the fake returns; null models an unconfigured provider.
  Uri? paymentApprovalUrl;

  @override
  Future<PaymentGatewayConfig> fetchPaymentConfig(String workspaceId) async =>
      PaymentGatewayConfig(
        providers: List.of(paymentProviders),
        missing: paymentMissing,
      );

  /// Per-provider server config the owner UI reads back.
  final Map<PaymentProvider, PaymentProviderStatus> paymentStatus = {};

  /// (provider, config) of setPaymentCredentials calls.
  final savedPaymentConfigs = <(PaymentProvider, Map<String, String>)>[];
  final clearedProviders = <PaymentProvider>[];

  @override
  Future<Map<PaymentProvider, PaymentProviderStatus>>
      fetchPaymentGatewayStatus(String workspaceId) async =>
          Map.of(paymentStatus);

  @override
  Future<void> setPaymentCredentials(
    String workspaceId,
    PaymentProvider provider,
    Map<String, String> config,
  ) async {
    savedPaymentConfigs.add((provider, config));
  }

  @override
  Future<void> clearPaymentProvider(
    String workspaceId,
    PaymentProvider provider,
  ) async {
    clearedProviders.add(provider);
  }

  @override
  Future<PaymentOrderStart> createPaymentOrder({
    required PaymentProvider provider,
    required String workspaceId,
    required String memberId,
    required int amountCents,
    required String currencyCode,
    required String period,
  }) async {
    paymentOrders.add((provider, amountCents));
    final url = paymentApprovalUrl;
    if (url == null) {
      return const PaymentOrderStart(missing: ['PAYPAL_CLIENT_ID']);
    }
    return PaymentOrderStart(approveUrl: url, orderId: 'order-1');
  }
}

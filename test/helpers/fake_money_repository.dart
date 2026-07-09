// SPDX-License-Identifier: MIT
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/money_repository.dart';
import 'package:deskilo/features/money/domain/plan.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/money/domain/statement.dart';

/// In-memory [MoneyRepository]; recorded payments are captured for
/// assertions (they only become ledger credits after confirmation).
class FakeMoneyRepository implements MoneyRepository {
  Statement statement = const Statement(
    period: '2026-07',
    planName: 'Half',
    baseFeeCents: 15000,
    includedHalfDays: 22,
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

  final plans = <Plan>[
    const Plan(
      id: 'plan-full',
      workspaceId: 'ws-1',
      name: 'Full',
      baseFeeCents: 25000,
      overageFeeCents: 0,
      active: true,
    ),
    const Plan(
      id: 'plan-half',
      workspaceId: 'ws-1',
      name: 'Half',
      baseFeeCents: 15000,
      includedHalfDays: 22,
      overageFeeCents: 800,
      active: true,
    ),
    const Plan(
      id: 'plan-flex',
      workspaceId: 'ws-1',
      name: 'Flex',
      baseFeeCents: 0,
      includedHalfDays: 0,
      overageFeeCents: 1500,
      active: true,
    ),
  ];

  @override
  Future<List<Plan>> fetchPlans(
    String workspaceId, {
    bool includeInactive = false,
  }) async =>
      plans.where((p) => includeInactive || p.active).toList();

  @override
  Future<void> createPlan({
    required String workspaceId,
    required String name,
    required int baseFeeCents,
    int? includedHalfDays,
    required int overageFeeCents,
  }) async {
    plans.add(
      Plan(
        id: 'plan-${plans.length + 1}',
        workspaceId: workspaceId,
        name: name,
        baseFeeCents: baseFeeCents,
        includedHalfDays: includedHalfDays,
        overageFeeCents: overageFeeCents,
        active: true,
      ),
    );
  }

  @override
  Future<void> updatePlan(Plan plan) async {
    final i = plans.indexWhere((p) => p.id == plan.id);
    if (i < 0) throw StateError('unknown plan');
    plans[i] = plan;
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

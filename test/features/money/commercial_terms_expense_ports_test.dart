// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2591 C4 — the commercial terms and the legacy expense adapter are ports
// of their own: the expense commands are built with a fake of that port
// alone, and the composed repository hands every call to the port it was
// given.
import 'package:deskilo/core/vat/supply_class.dart';
import 'package:deskilo/features/money/application/submit_expense.dart';
import 'package:deskilo/features/money/data/supabase_money_repository.dart';
import 'package:deskilo/features/money/domain/commercial_terms_repository.dart';
import 'package:deskilo/features/money/domain/expense_repartition.dart';
import 'package:deskilo/features/money/domain/expense_repository.dart';
import 'package:deskilo/features/money/domain/expense_schedule.dart';
import 'package:deskilo/features/money/domain/fee_band.dart';
import 'package:deskilo/features/money/domain/package.dart';
import 'package:deskilo/features/money/domain/price_negotiation.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/money/domain/subscription_levels.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Answers only what the test below asks; every other member throws, so a
/// consumer that reaches past its port fails loudly.
class _Terms implements CommercialTermsRepository {
  final calls = <String>[];

  @override
  Future<List<FeeBand>> fetchFeeBands(String workspaceId) async {
    calls.add('bands:$workspaceId');
    return const [];
  }

  @override
  Future<List<Package>> fetchPackages(
    String workspaceId, {
    bool includeInactive = false,
  }) async {
    calls.add('packages:$workspaceId:$includeInactive');
    return const [];
  }

  @override
  Future<PriceNegotiation> fetchPriceNegotiation(String memberId) =>
      throw UnimplementedError();

  @override
  Future<void> replaceFeeBands(String workspaceId, List<FeeBand> bands) =>
      throw UnimplementedError();

  @override
  Future<SubscriptionLevels> fetchSubscriptionLevels(String workspaceId) =>
      throw UnimplementedError();

  @override
  Future<void> setSubscriptionLevels(
    String workspaceId,
    SubscriptionLevels levels,
  ) => throw UnimplementedError();

  @override
  Future<List<ServiceItem>> fetchServices(
    String workspaceId, {
    bool includeInactive = false,
  }) => throw UnimplementedError();

  @override
  Future<ServiceItem> createService(
    String workspaceId, {
    required String name,
    required int priceCents,
    String? vatRateId,
    SupplyClass supplyClass = SupplyClass.property,
  }) => throw UnimplementedError();

  @override
  Future<ServiceItem> updateService(
    String serviceId, {
    String? name,
    int? priceCents,
    bool? active,
    String? vatRateId,
    SupplyClass? supplyClass,
  }) => throw UnimplementedError();

  @override
  Future<Package> createPackage(
    String workspaceId, {
    required String name,
    required int days,
    required int priceCents,
    String? vatRateId,
  }) => throw UnimplementedError();

  @override
  Future<Package> updatePackage(
    String packageId, {
    String? name,
    int? days,
    int? priceCents,
    bool? active,
    String? vatRateId,
  }) => throw UnimplementedError();

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
  }) => throw UnimplementedError();
}

class _Expenses implements ExpenseRepository {
  final calls = <String>[];

  @override
  Future<String> submitExpense({
    required String workspaceId,
    required int amountCents,
    required String category,
    String description = '',
    Map<String, Object?>? supply,
    Map<String, Object?>? vat,
  }) async {
    calls.add('submit:$workspaceId:$amountCents');
    return 'ev-1';
  }

  @override
  Future<List<ExpenseSchedule>> fetchExpenseSchedules(
    String workspaceId,
  ) async {
    calls.add('schedules:$workspaceId');
    return const [];
  }

  @override
  Future<String> distributeExpense({
    required String workspaceId,
    required String title,
    required int amountCents,
    required RepartitionMethod method,
    required String period,
    required List<RepartitionShare> shares,
    String? sourceEventId,
  }) => throw UnimplementedError();

  @override
  Future<List<ExpenseRepartition>> fetchExpenseRepartitions(
    String workspaceId,
  ) => throw UnimplementedError();

  @override
  Future<String> createExpenseSchedule({
    required String workspaceId,
    required String title,
    required int amountCents,
    required DateTime startsOn,
    required ScheduleUnit unit,
    int every = 1,
    int? repeatCount,
    DateTime? endsOn,
    String description = '',
  }) => throw UnimplementedError();

  @override
  Future<void> cancelExpenseSchedule(String scheduleId) =>
      throw UnimplementedError();

  @override
  Future<void> setExpenseScheduleVat(
    String scheduleId,
    Map<String, Object?>? vat,
  ) => throw UnimplementedError();

  @override
  Future<int> sweepExpenseSchedules(String workspaceId) =>
      throw UnimplementedError();

  @override
  Future<List<ExpenseOccurrence>> fetchExpenseOccurrences(String workspaceId) =>
      throw UnimplementedError();

  @override
  Future<void> confirmExpenseOccurrence({
    required String occurrenceId,
    required int amountCents,
    String reason = '',
    String? note,
  }) => throw UnimplementedError();
}

void main() {
  test('the composed repository hands each call to its own port', () async {
    final terms = _Terms();
    final expenses = _Expenses();
    final repo = SupabaseMoneyRepository(
      SupabaseClient('http://localhost', 'anon'),
      terms: terms,
      expenses: expenses,
    );

    await repo.fetchFeeBands('w1');
    await repo.fetchPackages('w1', includeInactive: true);
    await repo.fetchExpenseSchedules('w1');
    await repo.submitExpense(
      workspaceId: 'w1',
      amountCents: 500,
      category: 'supplies',
    );

    expect(terms.calls, ['bands:w1', 'packages:w1:true']);
    expect(expenses.calls, ['schedules:w1', 'submit:w1:500']);
  });

  test('submitting an expense needs the expense port alone', () async {
    final expenses = _Expenses();
    final outcome = await Expenses(
      expenses,
    ).submit('w1', const ExpenseDraft(amount: '12.00', category: 'supplies'));

    expect(outcome, ExpenseOutcome.submitted);

    expect(expenses.calls, ['submit:w1:1200']);
  });
}

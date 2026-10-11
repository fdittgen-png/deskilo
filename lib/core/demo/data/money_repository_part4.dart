// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'money_repository.dart';

// #2386 — part 4 of FakeMoneyRepository, split out of money_repository.dart so no
// file holds the whole class.
extension _FakeMoneyRepositoryPart4 on FakeMoneyRepository {

  Future<ServiceItem> _updateServiceImpl(
    String serviceId, {
    String? name,
    int? priceCents,
    bool? active,
    String? vatRateId,
    SupplyClass? supplyClass,
  }) async {
    final i = services.indexWhere((s) => s.id == serviceId);
    if (i < 0) throw StateError('unknown service');
    final updated = services[i].copyWith(
      supplyClass: supplyClass ?? services[i].supplyClass,
      name: name ?? services[i].name,
      priceCents: priceCents ?? services[i].priceCents,
      active: active ?? services[i].active,
      vatRateId: vatRateId ?? services[i].vatRateId,
    );
    services[i] = updated;
    return updated;
  }

  Future<void> _recordServiceChargeImpl({
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
      final now = kTestNow;
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
            'vat_percent': _vatPercentOf(service.vatRateId),
            'period': period ??
                yearMonth(now.year, now.month),
          },
          status: EventStatus.pending,
          createdAt: now,
        ),
      );
    }
  }

  Future<List<ExpenseSchedule>> _fetchExpenseSchedulesImpl(String workspaceId) async =>
      List.of(expenseSchedules);

  Future<String> _createExpenseScheduleImpl({
    required String workspaceId,
    required String title,
    required int amountCents,
    required DateTime startsOn,
    required ScheduleUnit unit,
    int every = 1,
    int? repeatCount,
    DateTime? endsOn,
    String description = '',
  }) async {
    createdSchedules.add((title: title, amountCents: amountCents, unit: unit,
        every: every, repeatCount: repeatCount, endsOn: endsOn));
    final schedule = ExpenseSchedule(
      id: 'schedule-${expenseSchedules.length + 1}',
      workspaceId: workspaceId,
      memberId: 'member-1',
      title: title,
      description: description,
      amountCents: amountCents,
      startsOn: startsOn,
      endsOn: endsOn,
      unit: unit,
      every: every,
      repeatCount: repeatCount,
    );
    expenseSchedules.add(schedule);
    return schedule.id;
  }

  Future<void> _cancelExpenseScheduleImpl(String scheduleId) async {
    final i = expenseSchedules.indexWhere((s) => s.id == scheduleId);
    if (i < 0) return;
    final s = expenseSchedules[i];
    expenseSchedules[i] = ExpenseSchedule(
      id: s.id, workspaceId: s.workspaceId, memberId: s.memberId,
      title: s.title, description: s.description, amountCents: s.amountCents,
      startsOn: s.startsOn, endsOn: s.endsOn, unit: s.unit, every: s.every,
      repeatCount: s.repeatCount, status: ScheduleStatus.ended,
      occurrencesDone: s.occurrencesDone,
    );
  }

  Future<int> _sweepExpenseSchedulesImpl(String workspaceId) async {
    sweptSchedules++;
    return 0;
  }

  Future<List<ExpenseOccurrence>> _fetchExpenseOccurrencesImpl(
          String workspaceId) async =>
      List.of(expenseOccurrences);

  Future<void> _confirmExpenseOccurrenceImpl({
    required String occurrenceId,
    required int amountCents,
    String reason = '',
    String? note,
  }) async {
    final i = expenseOccurrences.indexWhere((o) => o.id == occurrenceId);
    if (i < 0) throw StateError('unknown occurrence');
    final o = expenseOccurrences[i];
    final matches = amountCents == (o.scheduledAmountCents ?? o.amountCents) &&
        o.status == OccurrenceStatus.awaitingMember;
    if (!matches && reason.trim().isEmpty) {
      throw StateError('a different amount needs an explanation');
    }
    confirmedOccurrences.add(
        (occurrenceId: occurrenceId, amountCents: amountCents, reason: reason));
    expenseOccurrences[i] = ExpenseOccurrence(
      id: o.id, scheduleId: o.scheduleId, workspaceId: o.workspaceId,
      memberId: o.memberId, dueOn: o.dueOn, amountCents: amountCents,
      note: note ?? o.note, deviationReason: reason,
      status: matches ? OccurrenceStatus.added : OccurrenceStatus.pendingValidation,
      scheduleTitle: o.scheduleTitle,
      scheduledAmountCents: o.scheduledAmountCents,
    );
  }

  Future<String> _submitExpenseImpl({
    required String workspaceId,
    required int amountCents,
    required String category,
    String description = '',
    Map<String, Object?>? supply,
    Map<String, Object?>? vat,
  }) async {
    submittedExpenseVat.add(vat);
    submittedExpenses.add(
      (
        amountCents: amountCents,
        category: category,
        description: description,
        supply: supply,
      ),
    );
    return 'evt-expense-${submittedExpenses.length}';
  }

  Future<List<Package>> _fetchPackagesImpl(
    String workspaceId, {
    bool includeInactive = false,
  }) async =>
      packages.where((p) => includeInactive || p.active).toList()
        ..sort((a, b) => a.days.compareTo(b.days));

  Future<Package> _createPackageImpl(
    String workspaceId, {
    required String name,
    required int days,
    required int priceCents,
    String? vatRateId,
  }) async {
    final package = Package(
      id: 'package-${packages.length + 1}',
      workspaceId: workspaceId,
      name: name,
      days: days,
      priceCents: priceCents,
      vatRateId: vatRateId ?? '',
    );
    packages.add(package);
    return package;
  }

  Future<Package> _updatePackageImpl(
    String packageId, {
    String? name,
    int? days,
    int? priceCents,
    bool? active,
    String? vatRateId,
  }) async {
    final i = packages.indexWhere((p) => p.id == packageId);
    if (i < 0) throw StateError('unknown package');
    final updated = packages[i].copyWith(
      name: name ?? packages[i].name,
      days: days ?? packages[i].days,
      priceCents: priceCents ?? packages[i].priceCents,
      active: active ?? packages[i].active,
      vatRateId: vatRateId ?? packages[i].vatRateId,
    );
    packages[i] = updated;
    return updated;
  }

  Future<String> _buyPackageImpl(String workspaceId, String packageId) async {
    boughtPackages.add((workspaceId, packageId));
    return 'ext-${boughtPackages.length}';
  }

  Future<PaymentGatewayConfig> _fetchPaymentConfigImpl(String workspaceId) async =>
      PaymentGatewayConfig(
        providers: List.of(paymentProviders),
        missing: paymentMissing,
      );

  Future<Map<PaymentProvider, PaymentProviderStatus>>
      _fetchPaymentGatewayStatusImpl(String workspaceId) async =>
          Map.of(paymentStatus);

  Future<void> _setPaymentCredentialsImpl(
    String workspaceId,
    PaymentProvider provider,
    Map<String, String> config,
  ) async {
    savedPaymentConfigs.add((provider, config));
  }

  Future<void> _clearPaymentProviderImpl(
    String workspaceId,
    PaymentProvider provider,
  ) async {
    clearedProviders.add(provider);
  }

  Future<PaymentOrderStart> _createPaymentOrderImpl({
    required PaymentProvider provider,
    required String workspaceId,
    required String memberId,
    required int amountCents,
    required String currencyCode,
    required String period,
    String? requestId,
  }) async {
    paymentOrders.add((provider, amountCents));
    final url = paymentApprovalUrl;
    if (url == null) {
      return const PaymentOrderStart(missing: ['PAYPAL_CLIENT_ID']);
    }
    return PaymentOrderStart(approveUrl: url, orderId: 'order-1');
  }
}

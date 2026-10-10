// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kpi_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(kpiRepository)
final kpiRepositoryProvider = KpiRepositoryProvider._();

final class KpiRepositoryProvider
    extends $FunctionalProvider<KpiRepository, KpiRepository, KpiRepository>
    with $Provider<KpiRepository> {
  KpiRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'kpiRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$kpiRepositoryHash();

  @$internal
  @override
  $ProviderElement<KpiRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  KpiRepository create(Ref ref) {
    return kpiRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(KpiRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<KpiRepository>(value),
    );
  }
}

String _$kpiRepositoryHash() => r'1a139b032081f9b708982b6680164302b1cb1e4e';

/// #1924 — the finance KPIs.

@ProviderFor(financeKpiRepository)
final financeKpiRepositoryProvider = FinanceKpiRepositoryProvider._();

/// #1924 — the finance KPIs.

final class FinanceKpiRepositoryProvider
    extends
        $FunctionalProvider<
          FinanceKpiRepository,
          FinanceKpiRepository,
          FinanceKpiRepository
        >
    with $Provider<FinanceKpiRepository> {
  /// #1924 — the finance KPIs.
  FinanceKpiRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'financeKpiRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$financeKpiRepositoryHash();

  @$internal
  @override
  $ProviderElement<FinanceKpiRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FinanceKpiRepository create(Ref ref) {
    return financeKpiRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FinanceKpiRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FinanceKpiRepository>(value),
    );
  }
}

String _$financeKpiRepositoryHash() =>
    r'b9cc57494516cc4621443481ae610199d4823002';

/// One read per workspace and months, shared by every finance card.

@ProviderFor(financeSummary)
final financeSummaryProvider = FinanceSummaryFamily._();

/// One read per workspace and months, shared by every finance card.

final class FinanceSummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<FinanceSummaryKpi>,
          FinanceSummaryKpi,
          FutureOr<FinanceSummaryKpi>
        >
    with
        $FutureModifier<FinanceSummaryKpi>,
        $FutureProvider<FinanceSummaryKpi> {
  /// One read per workspace and months, shared by every finance card.
  FinanceSummaryProvider._({
    required FinanceSummaryFamily super.from,
    required (String, String, String) super.argument,
  }) : super(
         retry: null,
         name: r'financeSummaryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$financeSummaryHash();

  @override
  String toString() {
    return r'financeSummaryProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<FinanceSummaryKpi> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<FinanceSummaryKpi> create(Ref ref) {
    final argument = this.argument as (String, String, String);
    return financeSummary(ref, argument.$1, argument.$2, argument.$3);
  }

  @override
  bool operator ==(Object other) {
    return other is FinanceSummaryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$financeSummaryHash() => r'da8fae35bba78af3e3c846bebb00a873e553a3c4';

/// One read per workspace and months, shared by every finance card.

final class FinanceSummaryFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<FinanceSummaryKpi>,
          (String, String, String)
        > {
  FinanceSummaryFamily._()
    : super(
        retry: null,
        name: r'financeSummaryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One read per workspace and months, shared by every finance card.

  FinanceSummaryProvider call(
    String workspaceId,
    String fromMonth,
    String toMonth,
  ) => FinanceSummaryProvider._(
    argument: (workspaceId, fromMonth, toMonth),
    from: this,
  );

  @override
  String toString() => r'financeSummaryProvider';
}

/// Seat utilisation of one calendar month, on the workspace clock: the
/// month starts at local midnight of its first day, whatever DST does.

@ProviderFor(seatCapacityMonth)
final seatCapacityMonthProvider = SeatCapacityMonthFamily._();

/// Seat utilisation of one calendar month, on the workspace clock: the
/// month starts at local midnight of its first day, whatever DST does.

final class SeatCapacityMonthProvider
    extends
        $FunctionalProvider<
          AsyncValue<SeatCapacityKpi>,
          SeatCapacityKpi,
          FutureOr<SeatCapacityKpi>
        >
    with $FutureModifier<SeatCapacityKpi>, $FutureProvider<SeatCapacityKpi> {
  /// Seat utilisation of one calendar month, on the workspace clock: the
  /// month starts at local midnight of its first day, whatever DST does.
  SeatCapacityMonthProvider._({
    required SeatCapacityMonthFamily super.from,
    required (String, int, int) super.argument,
  }) : super(
         retry: null,
         name: r'seatCapacityMonthProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$seatCapacityMonthHash();

  @override
  String toString() {
    return r'seatCapacityMonthProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<SeatCapacityKpi> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SeatCapacityKpi> create(Ref ref) {
    final argument = this.argument as (String, int, int);
    return seatCapacityMonth(ref, argument.$1, argument.$2, argument.$3);
  }

  @override
  bool operator ==(Object other) {
    return other is SeatCapacityMonthProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$seatCapacityMonthHash() => r'e1d12eb1fe5f16a64d47fcf3c97712004af8ea38';

/// Seat utilisation of one calendar month, on the workspace clock: the
/// month starts at local midnight of its first day, whatever DST does.

final class SeatCapacityMonthFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<SeatCapacityKpi>,
          (String, int, int)
        > {
  SeatCapacityMonthFamily._()
    : super(
        retry: null,
        name: r'seatCapacityMonthProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Seat utilisation of one calendar month, on the workspace clock: the
  /// month starts at local midnight of its first day, whatever DST does.

  SeatCapacityMonthProvider call(String workspaceId, int year, int month) =>
      SeatCapacityMonthProvider._(
        argument: (workspaceId, year, month),
        from: this,
      );

  @override
  String toString() => r'seatCapacityMonthProvider';
}

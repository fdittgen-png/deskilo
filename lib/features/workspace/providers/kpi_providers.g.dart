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

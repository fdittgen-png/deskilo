// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sales_kpi_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(salesKpiRepository)
final salesKpiRepositoryProvider = SalesKpiRepositoryProvider._();

final class SalesKpiRepositoryProvider
    extends
        $FunctionalProvider<
          SalesKpiRepository,
          SalesKpiRepository,
          SalesKpiRepository
        >
    with $Provider<SalesKpiRepository> {
  SalesKpiRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'salesKpiRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$salesKpiRepositoryHash();

  @$internal
  @override
  $ProviderElement<SalesKpiRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SalesKpiRepository create(Ref ref) {
    return salesKpiRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SalesKpiRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SalesKpiRepository>(value),
    );
  }
}

String _$salesKpiRepositoryHash() =>
    r'700a6a267d69d9d4c1ea73f8d086928487b45d01';

@ProviderFor(salesQuality)
final salesQualityProvider = SalesQualityFamily._();

final class SalesQualityProvider
    extends
        $FunctionalProvider<
          AsyncValue<SalesQualityKpi>,
          SalesQualityKpi,
          FutureOr<SalesQualityKpi>
        >
    with $FutureModifier<SalesQualityKpi>, $FutureProvider<SalesQualityKpi> {
  SalesQualityProvider._({
    required SalesQualityFamily super.from,
    required (String, String, String) super.argument,
  }) : super(
         retry: kpiRetry,
         name: r'salesQualityProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$salesQualityHash();

  @override
  String toString() {
    return r'salesQualityProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<SalesQualityKpi> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SalesQualityKpi> create(Ref ref) {
    final argument = this.argument as (String, String, String);
    return salesQuality(ref, argument.$1, argument.$2, argument.$3);
  }

  @override
  bool operator ==(Object other) {
    return other is SalesQualityProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$salesQualityHash() => r'0269730ed2ad7a55ef3117c1011751fc4bfd53c1';

final class SalesQualityFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<SalesQualityKpi>,
          (String, String, String)
        > {
  SalesQualityFamily._()
    : super(
        retry: kpiRetry,
        name: r'salesQualityProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SalesQualityProvider call(
    String workspaceId,
    String fromMonth,
    String toMonth,
  ) => SalesQualityProvider._(
    argument: (workspaceId, fromMonth, toMonth),
    from: this,
  );

  @override
  String toString() => r'salesQualityProvider';
}

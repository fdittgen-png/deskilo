// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_kpi_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(customerKpiRepository)
final customerKpiRepositoryProvider = CustomerKpiRepositoryProvider._();

final class CustomerKpiRepositoryProvider
    extends
        $FunctionalProvider<
          CustomerKpiRepository,
          CustomerKpiRepository,
          CustomerKpiRepository
        >
    with $Provider<CustomerKpiRepository> {
  CustomerKpiRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customerKpiRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customerKpiRepositoryHash();

  @$internal
  @override
  $ProviderElement<CustomerKpiRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CustomerKpiRepository create(Ref ref) {
    return customerKpiRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CustomerKpiRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CustomerKpiRepository>(value),
    );
  }
}

String _$customerKpiRepositoryHash() =>
    r'7223ea5e24ba62c17077c54d74ec68d3d7b50227';

@ProviderFor(customerQuality)
final customerQualityProvider = CustomerQualityFamily._();

final class CustomerQualityProvider
    extends
        $FunctionalProvider<
          AsyncValue<CustomerQualityKpi>,
          CustomerQualityKpi,
          FutureOr<CustomerQualityKpi>
        >
    with
        $FutureModifier<CustomerQualityKpi>,
        $FutureProvider<CustomerQualityKpi> {
  CustomerQualityProvider._({
    required CustomerQualityFamily super.from,
    required (String, String, String) super.argument,
  }) : super(
         retry: kpiRetry,
         name: r'customerQualityProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$customerQualityHash();

  @override
  String toString() {
    return r'customerQualityProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<CustomerQualityKpi> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CustomerQualityKpi> create(Ref ref) {
    final argument = this.argument as (String, String, String);
    return customerQuality(ref, argument.$1, argument.$2, argument.$3);
  }

  @override
  bool operator ==(Object other) {
    return other is CustomerQualityProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$customerQualityHash() => r'd4a578bbcc1c7258a8e8caf06cae6cbf828ed0ee';

final class CustomerQualityFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<CustomerQualityKpi>,
          (String, String, String)
        > {
  CustomerQualityFamily._()
    : super(
        retry: kpiRetry,
        name: r'customerQualityProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CustomerQualityProvider call(
    String workspaceId,
    String fromMonth,
    String toMonth,
  ) => CustomerQualityProvider._(
    argument: (workspaceId, fromMonth, toMonth),
    from: this,
  );

  @override
  String toString() => r'customerQualityProvider';
}

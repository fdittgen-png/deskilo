// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vendor_kpi_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(vendorKpiRepository)
final vendorKpiRepositoryProvider = VendorKpiRepositoryProvider._();

final class VendorKpiRepositoryProvider
    extends
        $FunctionalProvider<
          VendorKpiRepository,
          VendorKpiRepository,
          VendorKpiRepository
        >
    with $Provider<VendorKpiRepository> {
  VendorKpiRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vendorKpiRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vendorKpiRepositoryHash();

  @$internal
  @override
  $ProviderElement<VendorKpiRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VendorKpiRepository create(Ref ref) {
    return vendorKpiRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VendorKpiRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VendorKpiRepository>(value),
    );
  }
}

String _$vendorKpiRepositoryHash() =>
    r'8b11e4f453ffb8e34755f7d70e84b81e4b70b0b1';

@ProviderFor(vendorQuality)
final vendorQualityProvider = VendorQualityFamily._();

final class VendorQualityProvider
    extends
        $FunctionalProvider<
          AsyncValue<VendorQualityKpi>,
          VendorQualityKpi,
          FutureOr<VendorQualityKpi>
        >
    with $FutureModifier<VendorQualityKpi>, $FutureProvider<VendorQualityKpi> {
  VendorQualityProvider._({
    required VendorQualityFamily super.from,
    required (String, String, String) super.argument,
  }) : super(
         retry: kpiRetry,
         name: r'vendorQualityProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$vendorQualityHash();

  @override
  String toString() {
    return r'vendorQualityProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<VendorQualityKpi> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<VendorQualityKpi> create(Ref ref) {
    final argument = this.argument as (String, String, String);
    return vendorQuality(ref, argument.$1, argument.$2, argument.$3);
  }

  @override
  bool operator ==(Object other) {
    return other is VendorQualityProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$vendorQualityHash() => r'564981f90d6c7a108ecff33bd62d763a19c2fb3a';

final class VendorQualityFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<VendorQualityKpi>,
          (String, String, String)
        > {
  VendorQualityFamily._()
    : super(
        retry: kpiRetry,
        name: r'vendorQualityProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  VendorQualityProvider call(
    String workspaceId,
    String fromMonth,
    String toMonth,
  ) => VendorQualityProvider._(
    argument: (workspaceId, fromMonth, toMonth),
    from: this,
  );

  @override
  String toString() => r'vendorQualityProvider';
}

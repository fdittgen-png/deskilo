// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cost_allocation_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(costAllocationRepository)
final costAllocationRepositoryProvider = CostAllocationRepositoryProvider._();

final class CostAllocationRepositoryProvider
    extends
        $FunctionalProvider<
          CostAllocationRepository,
          CostAllocationRepository,
          CostAllocationRepository
        >
    with $Provider<CostAllocationRepository> {
  CostAllocationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'costAllocationRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$costAllocationRepositoryHash();

  @$internal
  @override
  $ProviderElement<CostAllocationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CostAllocationRepository create(Ref ref) {
    return costAllocationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CostAllocationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CostAllocationRepository>(value),
    );
  }
}

String _$costAllocationRepositoryHash() =>
    r'735d7fcb8b35a40bf3f5c780284cf2b709bd6f5d';

/// One read per workspace and months.

@ProviderFor(costAllocation)
final costAllocationProvider = CostAllocationFamily._();

/// One read per workspace and months.

final class CostAllocationProvider
    extends
        $FunctionalProvider<
          AsyncValue<CostAllocationKpi>,
          CostAllocationKpi,
          FutureOr<CostAllocationKpi>
        >
    with
        $FutureModifier<CostAllocationKpi>,
        $FutureProvider<CostAllocationKpi> {
  /// One read per workspace and months.
  CostAllocationProvider._({
    required CostAllocationFamily super.from,
    required (String, String, String) super.argument,
  }) : super(
         retry: kpiRetry,
         name: r'costAllocationProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$costAllocationHash();

  @override
  String toString() {
    return r'costAllocationProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<CostAllocationKpi> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CostAllocationKpi> create(Ref ref) {
    final argument = this.argument as (String, String, String);
    return costAllocation(ref, argument.$1, argument.$2, argument.$3);
  }

  @override
  bool operator ==(Object other) {
    return other is CostAllocationProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$costAllocationHash() => r'035dcb49553257c5b255140e2d50bf3133f84e58';

/// One read per workspace and months.

final class CostAllocationFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<CostAllocationKpi>,
          (String, String, String)
        > {
  CostAllocationFamily._()
    : super(
        retry: kpiRetry,
        name: r'costAllocationProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One read per workspace and months.

  CostAllocationProvider call(
    String workspaceId,
    String fromMonth,
    String toMonth,
  ) => CostAllocationProvider._(
    argument: (workspaceId, fromMonth, toMonth),
    from: this,
  );

  @override
  String toString() => r'costAllocationProvider';
}

/// Every revision of the workspace's rules; the editor invalidates it
/// after a save.

@ProviderFor(allocationRules)
final allocationRulesProvider = AllocationRulesFamily._();

/// Every revision of the workspace's rules; the editor invalidates it
/// after a save.

final class AllocationRulesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AllocationRule>>,
          List<AllocationRule>,
          FutureOr<List<AllocationRule>>
        >
    with
        $FutureModifier<List<AllocationRule>>,
        $FutureProvider<List<AllocationRule>> {
  /// Every revision of the workspace's rules; the editor invalidates it
  /// after a save.
  AllocationRulesProvider._({
    required AllocationRulesFamily super.from,
    required String super.argument,
  }) : super(
         retry: kpiRetry,
         name: r'allocationRulesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$allocationRulesHash();

  @override
  String toString() {
    return r'allocationRulesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<AllocationRule>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AllocationRule>> create(Ref ref) {
    final argument = this.argument as String;
    return allocationRules(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AllocationRulesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$allocationRulesHash() => r'c32ec8fdbadb815b2675f389f0b9015cf299dc42';

/// Every revision of the workspace's rules; the editor invalidates it
/// after a save.

final class AllocationRulesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<AllocationRule>>, String> {
  AllocationRulesFamily._()
    : super(
        retry: kpiRetry,
        name: r'allocationRulesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Every revision of the workspace's rules; the editor invalidates it
  /// after a save.

  AllocationRulesProvider call(String workspaceId) =>
      AllocationRulesProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'allocationRulesProvider';
}

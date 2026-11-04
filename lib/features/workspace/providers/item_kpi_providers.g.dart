// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item_kpi_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(itemKpiRepository)
final itemKpiRepositoryProvider = ItemKpiRepositoryProvider._();

final class ItemKpiRepositoryProvider
    extends
        $FunctionalProvider<
          ItemKpiRepository,
          ItemKpiRepository,
          ItemKpiRepository
        >
    with $Provider<ItemKpiRepository> {
  ItemKpiRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'itemKpiRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$itemKpiRepositoryHash();

  @$internal
  @override
  $ProviderElement<ItemKpiRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ItemKpiRepository create(Ref ref) {
    return itemKpiRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ItemKpiRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ItemKpiRepository>(value),
    );
  }
}

String _$itemKpiRepositoryHash() => r'297883b2a4b765ff77d69394efabaed850adbc73';

@ProviderFor(itemMargins)
final itemMarginsProvider = ItemMarginsFamily._();

final class ItemMarginsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ItemMarginsKpi>,
          ItemMarginsKpi,
          FutureOr<ItemMarginsKpi>
        >
    with $FutureModifier<ItemMarginsKpi>, $FutureProvider<ItemMarginsKpi> {
  ItemMarginsProvider._({
    required ItemMarginsFamily super.from,
    required (String, String, String) super.argument,
  }) : super(
         retry: kpiRetry,
         name: r'itemMarginsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$itemMarginsHash();

  @override
  String toString() {
    return r'itemMarginsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<ItemMarginsKpi> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ItemMarginsKpi> create(Ref ref) {
    final argument = this.argument as (String, String, String);
    return itemMargins(ref, argument.$1, argument.$2, argument.$3);
  }

  @override
  bool operator ==(Object other) {
    return other is ItemMarginsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$itemMarginsHash() => r'9a054e4f774363b99270f75790d00b912813ace1';

final class ItemMarginsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<ItemMarginsKpi>,
          (String, String, String)
        > {
  ItemMarginsFamily._()
    : super(
        retry: kpiRetry,
        name: r'itemMarginsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ItemMarginsProvider call(
    String workspaceId,
    String fromMonth,
    String toMonth,
  ) => ItemMarginsProvider._(
    argument: (workspaceId, fromMonth, toMonth),
    from: this,
  );

  @override
  String toString() => r'itemMarginsProvider';
}

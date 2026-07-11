// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accessory_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(accessoryRepository)
final accessoryRepositoryProvider = AccessoryRepositoryProvider._();

final class AccessoryRepositoryProvider
    extends
        $FunctionalProvider<
          AccessoryRepository,
          AccessoryRepository,
          AccessoryRepository
        >
    with $Provider<AccessoryRepository> {
  AccessoryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accessoryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accessoryRepositoryHash();

  @$internal
  @override
  $ProviderElement<AccessoryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccessoryRepository create(Ref ref) {
    return accessoryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccessoryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccessoryRepository>(value),
    );
  }
}

String _$accessoryRepositoryHash() =>
    r'325bf1622e960a13f1c4cdfe705d9c8885506c67';

/// Accessory catalog of the active workspace, ordered by sort_order then
/// name. The catalog editor (#167) passes [includeInactive]; booking
/// display (#169) and the seat editor (#168) use the active-only default.

@ProviderFor(accessories)
final accessoriesProvider = AccessoriesFamily._();

/// Accessory catalog of the active workspace, ordered by sort_order then
/// name. The catalog editor (#167) passes [includeInactive]; booking
/// display (#169) and the seat editor (#168) use the active-only default.

final class AccessoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Accessory>>,
          List<Accessory>,
          FutureOr<List<Accessory>>
        >
    with $FutureModifier<List<Accessory>>, $FutureProvider<List<Accessory>> {
  /// Accessory catalog of the active workspace, ordered by sort_order then
  /// name. The catalog editor (#167) passes [includeInactive]; booking
  /// display (#169) and the seat editor (#168) use the active-only default.
  AccessoriesProvider._({
    required AccessoriesFamily super.from,
    required bool super.argument,
  }) : super(
         retry: null,
         name: r'accessoriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accessoriesHash();

  @override
  String toString() {
    return r'accessoriesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Accessory>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Accessory>> create(Ref ref) {
    final argument = this.argument as bool;
    return accessories(ref, includeInactive: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AccessoriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accessoriesHash() => r'eeed0a54dbc8ee68a5033b4ae1de779f68867ba2';

/// Accessory catalog of the active workspace, ordered by sort_order then
/// name. The catalog editor (#167) passes [includeInactive]; booking
/// display (#169) and the seat editor (#168) use the active-only default.

final class AccessoriesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Accessory>>, bool> {
  AccessoriesFamily._()
    : super(
        retry: null,
        name: r'accessoriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Accessory catalog of the active workspace, ordered by sort_order then
  /// name. The catalog editor (#167) passes [includeInactive]; booking
  /// display (#169) and the seat editor (#168) use the active-only default.

  AccessoriesProvider call({bool includeInactive = false}) =>
      AccessoriesProvider._(argument: includeInactive, from: this);

  @override
  String toString() => r'accessoriesProvider';
}

/// seat id → assigned accessory ids across the active workspace (one
/// fetch feeds the seat editor #168 and the booking display #169).

@ProviderFor(seatAccessories)
final seatAccessoriesProvider = SeatAccessoriesProvider._();

/// seat id → assigned accessory ids across the active workspace (one
/// fetch feeds the seat editor #168 and the booking display #169).

final class SeatAccessoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, Set<String>>>,
          Map<String, Set<String>>,
          FutureOr<Map<String, Set<String>>>
        >
    with
        $FutureModifier<Map<String, Set<String>>>,
        $FutureProvider<Map<String, Set<String>>> {
  /// seat id → assigned accessory ids across the active workspace (one
  /// fetch feeds the seat editor #168 and the booking display #169).
  SeatAccessoriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'seatAccessoriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$seatAccessoriesHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, Set<String>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, Set<String>>> create(Ref ref) {
    return seatAccessories(ref);
  }
}

String _$seatAccessoriesHash() => r'113f0945cd52f2f7d793c488a44b409192c90b30';

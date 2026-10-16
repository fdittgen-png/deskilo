// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'charging_station_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(chargingStationRepository)
final chargingStationRepositoryProvider = ChargingStationRepositoryProvider._();

final class ChargingStationRepositoryProvider
    extends
        $FunctionalProvider<
          ChargingStationRepository,
          ChargingStationRepository,
          ChargingStationRepository
        >
    with $Provider<ChargingStationRepository> {
  ChargingStationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chargingStationRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chargingStationRepositoryHash();

  @$internal
  @override
  $ProviderElement<ChargingStationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ChargingStationRepository create(Ref ref) {
    return chargingStationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChargingStationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChargingStationRepository>(value),
    );
  }
}

String _$chargingStationRepositoryHash() =>
    r'1f0fa4382bc69c43942ccef493e82653577f9ec0';

@ProviderFor(planResourceRepository)
final planResourceRepositoryProvider = PlanResourceRepositoryProvider._();

final class PlanResourceRepositoryProvider
    extends
        $FunctionalProvider<
          PlanResourceRepository,
          PlanResourceRepository,
          PlanResourceRepository
        >
    with $Provider<PlanResourceRepository> {
  PlanResourceRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'planResourceRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$planResourceRepositoryHash();

  @$internal
  @override
  $ProviderElement<PlanResourceRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PlanResourceRepository create(Ref ref) {
    return planResourceRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlanResourceRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlanResourceRepository>(value),
    );
  }
}

String _$planResourceRepositoryHash() =>
    r'70a7d2ab7668f816aa22567b5531044aa4509f8b';

@ProviderFor(resourceCommands)
final resourceCommandsProvider = ResourceCommandsProvider._();

final class ResourceCommandsProvider
    extends
        $FunctionalProvider<
          ResourceCommands,
          ResourceCommands,
          ResourceCommands
        >
    with $Provider<ResourceCommands> {
  ResourceCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'resourceCommandsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$resourceCommandsHash();

  @$internal
  @override
  $ProviderElement<ResourceCommands> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ResourceCommands create(Ref ref) {
    return resourceCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ResourceCommands value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ResourceCommands>(value),
    );
  }
}

String _$resourceCommandsHash() => r'647aa57351c84bb986f7f5fc0fb80e251bd8cf2a';

/// seat id → the charging station of that EV slot (#2631), across the
/// workspace [workspaceId]. One fetch feeds the plan editor and the reserve
/// list.

@ProviderFor(chargingStations)
final chargingStationsProvider = ChargingStationsFamily._();

/// seat id → the charging station of that EV slot (#2631), across the
/// workspace [workspaceId]. One fetch feeds the plan editor and the reserve
/// list.

final class ChargingStationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, ChargingStation>>,
          Map<String, ChargingStation>,
          FutureOr<Map<String, ChargingStation>>
        >
    with
        $FutureModifier<Map<String, ChargingStation>>,
        $FutureProvider<Map<String, ChargingStation>> {
  /// seat id → the charging station of that EV slot (#2631), across the
  /// workspace [workspaceId]. One fetch feeds the plan editor and the reserve
  /// list.
  ChargingStationsProvider._({
    required ChargingStationsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'chargingStationsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$chargingStationsHash();

  @override
  String toString() {
    return r'chargingStationsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Map<String, ChargingStation>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, ChargingStation>> create(Ref ref) {
    final argument = this.argument as String;
    return chargingStations(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ChargingStationsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chargingStationsHash() => r'3128163af9d923741bff800f3ab6d28a625fee4f';

/// seat id → the charging station of that EV slot (#2631), across the
/// workspace [workspaceId]. One fetch feeds the plan editor and the reserve
/// list.

final class ChargingStationsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<Map<String, ChargingStation>>,
          String
        > {
  ChargingStationsFamily._()
    : super(
        retry: null,
        name: r'chargingStationsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// seat id → the charging station of that EV slot (#2631), across the
  /// workspace [workspaceId]. One fetch feeds the plan editor and the reserve
  /// list.

  ChargingStationsProvider call(String workspaceId) =>
      ChargingStationsProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'chargingStationsProvider';
}

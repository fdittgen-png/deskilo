// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'floor_plan_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(floorPlanRepository)
final floorPlanRepositoryProvider = FloorPlanRepositoryProvider._();

final class FloorPlanRepositoryProvider
    extends
        $FunctionalProvider<
          FloorPlanRepository,
          FloorPlanRepository,
          FloorPlanRepository
        >
    with $Provider<FloorPlanRepository> {
  FloorPlanRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'floorPlanRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$floorPlanRepositoryHash();

  @$internal
  @override
  $ProviderElement<FloorPlanRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FloorPlanRepository create(Ref ref) {
    return floorPlanRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FloorPlanRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FloorPlanRepository>(value),
    );
  }
}

String _$floorPlanRepositoryHash() =>
    r'a434ef037e2ecf90963189df3532ff953f06a4eb';

/// Levels of the active workspace, sorted by sort_order.

@ProviderFor(levels)
final levelsProvider = LevelsProvider._();

/// Levels of the active workspace, sorted by sort_order.

final class LevelsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Level>>,
          List<Level>,
          FutureOr<List<Level>>
        >
    with $FutureModifier<List<Level>>, $FutureProvider<List<Level>> {
  /// Levels of the active workspace, sorted by sort_order.
  LevelsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'levelsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$levelsHash();

  @$internal
  @override
  $FutureProviderElement<List<Level>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Level>> create(Ref ref) {
    return levels(ref);
  }
}

String _$levelsHash() => r'ee07fd01eae058daa2d2411ab9204f62d99c3027';

/// Everything drawn on one level. Family-keyed by level id.

@ProviderFor(floorPlan)
final floorPlanProvider = FloorPlanFamily._();

/// Everything drawn on one level. Family-keyed by level id.

final class FloorPlanProvider
    extends
        $FunctionalProvider<
          AsyncValue<FloorPlan>,
          FloorPlan,
          FutureOr<FloorPlan>
        >
    with $FutureModifier<FloorPlan>, $FutureProvider<FloorPlan> {
  /// Everything drawn on one level. Family-keyed by level id.
  FloorPlanProvider._({
    required FloorPlanFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'floorPlanProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$floorPlanHash();

  @override
  String toString() {
    return r'floorPlanProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<FloorPlan> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<FloorPlan> create(Ref ref) {
    final argument = this.argument as String;
    return floorPlan(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FloorPlanProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$floorPlanHash() => r'028b3e4468d2d5bb48348bbd181c683ee7e560ec';

/// Everything drawn on one level. Family-keyed by level id.

final class FloorPlanFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<FloorPlan>, String> {
  FloorPlanFamily._()
    : super(
        retry: null,
        name: r'floorPlanProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Everything drawn on one level. Family-keyed by level id.

  FloorPlanProvider call(String levelId) =>
      FloorPlanProvider._(argument: levelId, from: this);

  @override
  String toString() => r'floorPlanProvider';
}

/// The level's decoded background image (0036), or null when none is set.
/// Fetched bytes are decoded once and cached; the plan and editor paint
/// it behind the grid. Failures degrade to null — the schematic still
/// renders, the photo is just absent.

@ProviderFor(levelBackground)
final levelBackgroundProvider = LevelBackgroundFamily._();

/// The level's decoded background image (0036), or null when none is set.
/// Fetched bytes are decoded once and cached; the plan and editor paint
/// it behind the grid. Failures degrade to null — the schematic still
/// renders, the photo is just absent.

final class LevelBackgroundProvider
    extends
        $FunctionalProvider<
          AsyncValue<ui.Image?>,
          ui.Image?,
          FutureOr<ui.Image?>
        >
    with $FutureModifier<ui.Image?>, $FutureProvider<ui.Image?> {
  /// The level's decoded background image (0036), or null when none is set.
  /// Fetched bytes are decoded once and cached; the plan and editor paint
  /// it behind the grid. Failures degrade to null — the schematic still
  /// renders, the photo is just absent.
  LevelBackgroundProvider._({
    required LevelBackgroundFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'levelBackgroundProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$levelBackgroundHash();

  @override
  String toString() {
    return r'levelBackgroundProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ui.Image?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<ui.Image?> create(Ref ref) {
    final argument = this.argument as String;
    return levelBackground(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LevelBackgroundProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$levelBackgroundHash() => r'b1a6eb8debeb208e9b18b304f3fb7bc77f7b2422';

/// The level's decoded background image (0036), or null when none is set.
/// Fetched bytes are decoded once and cached; the plan and editor paint
/// it behind the grid. Failures degrade to null — the schematic still
/// renders, the photo is just absent.

final class LevelBackgroundFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ui.Image?>, String> {
  LevelBackgroundFamily._()
    : super(
        retry: null,
        name: r'levelBackgroundProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The level's decoded background image (0036), or null when none is set.
  /// Fetched bytes are decoded once and cached; the plan and editor paint
  /// it behind the grid. Failures degrade to null — the schematic still
  /// renders, the photo is just absent.

  LevelBackgroundProvider call(String levelId) =>
      LevelBackgroundProvider._(argument: levelId, from: this);

  @override
  String toString() => r'levelBackgroundProvider';
}

/// seat/office id → display name for the active workspace (labels in the
/// calendar and event feeds without loading every level's plan).

@ProviderFor(targetNames)
final targetNamesProvider = TargetNamesProvider._();

/// seat/office id → display name for the active workspace (labels in the
/// calendar and event feeds without loading every level's plan).

final class TargetNamesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, String>>,
          Map<String, String>,
          FutureOr<Map<String, String>>
        >
    with
        $FutureModifier<Map<String, String>>,
        $FutureProvider<Map<String, String>> {
  /// seat/office id → display name for the active workspace (labels in the
  /// calendar and event feeds without loading every level's plan).
  TargetNamesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'targetNamesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$targetNamesHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, String>> create(Ref ref) {
    return targetNames(ref);
  }
}

String _$targetNamesHash() => r'df73e2ff7e54720a61304621ca40f9b26abf26b1';

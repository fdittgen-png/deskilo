// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bi_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(biModuleResult)
final biModuleResultProvider = BiModuleResultFamily._();

final class BiModuleResultProvider
    extends
        $FunctionalProvider<AsyncValue<BiResult>, BiResult, FutureOr<BiResult>>
    with $FutureModifier<BiResult>, $FutureProvider<BiResult> {
  BiModuleResultProvider._({
    required BiModuleResultFamily super.from,
    required (String, String, BiQueryContext) super.argument,
  }) : super(
         retry: biRetry,
         name: r'biModuleResultProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$biModuleResultHash();

  @override
  String toString() {
    return r'biModuleResultProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<BiResult> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<BiResult> create(Ref ref) {
    final argument = this.argument as (String, String, BiQueryContext);
    return biModuleResult(ref, argument.$1, argument.$2, argument.$3);
  }

  @override
  bool operator ==(Object other) {
    return other is BiModuleResultProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$biModuleResultHash() => r'a3829148dea4c39c0d49b51bcfd1bbdc716582ec';

final class BiModuleResultFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<BiResult>,
          (String, String, BiQueryContext)
        > {
  BiModuleResultFamily._()
    : super(
        retry: biRetry,
        name: r'biModuleResultProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BiModuleResultProvider call(
    String workspaceId,
    String moduleId,
    BiQueryContext context,
  ) => BiModuleResultProvider._(
    argument: (workspaceId, moduleId, context),
    from: this,
  );

  @override
  String toString() => r'biModuleResultProvider';
}

/// The module's own figure for each of the [count] periods ending at
/// [end], oldest first. Each is the same read the page makes for one
/// period; a period the data does not know (before the history, or a read
/// that failed) is a gap in the series, never a zero, and never fails the
/// others.

@ProviderFor(biModuleSeries)
final biModuleSeriesProvider = BiModuleSeriesFamily._();

/// The module's own figure for each of the [count] periods ending at
/// [end], oldest first. Each is the same read the page makes for one
/// period; a period the data does not know (before the history, or a read
/// that failed) is a gap in the series, never a zero, and never fails the
/// others.

final class BiModuleSeriesProvider
    extends
        $FunctionalProvider<AsyncValue<BiSeries>, BiSeries, FutureOr<BiSeries>>
    with $FutureModifier<BiSeries>, $FutureProvider<BiSeries> {
  /// The module's own figure for each of the [count] periods ending at
  /// [end], oldest first. Each is the same read the page makes for one
  /// period; a period the data does not know (before the history, or a read
  /// that failed) is a gap in the series, never a zero, and never fails the
  /// others.
  BiModuleSeriesProvider._({
    required BiModuleSeriesFamily super.from,
    required (String, String, BiGrain, BiPeriod, int) super.argument,
  }) : super(
         retry: biRetry,
         name: r'biModuleSeriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$biModuleSeriesHash();

  @override
  String toString() {
    return r'biModuleSeriesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<BiSeries> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<BiSeries> create(Ref ref) {
    final argument = this.argument as (String, String, BiGrain, BiPeriod, int);
    return biModuleSeries(
      ref,
      argument.$1,
      argument.$2,
      argument.$3,
      argument.$4,
      argument.$5,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BiModuleSeriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$biModuleSeriesHash() => r'79957d850da793cefa4b889b2c2eb3c5ac41647d';

/// The module's own figure for each of the [count] periods ending at
/// [end], oldest first. Each is the same read the page makes for one
/// period; a period the data does not know (before the history, or a read
/// that failed) is a gap in the series, never a zero, and never fails the
/// others.

final class BiModuleSeriesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<BiSeries>,
          (String, String, BiGrain, BiPeriod, int)
        > {
  BiModuleSeriesFamily._()
    : super(
        retry: biRetry,
        name: r'biModuleSeriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The module's own figure for each of the [count] periods ending at
  /// [end], oldest first. Each is the same read the page makes for one
  /// period; a period the data does not know (before the history, or a read
  /// that failed) is a gap in the series, never a zero, and never fails the
  /// others.

  BiModuleSeriesProvider call(
    String workspaceId,
    String moduleId,
    BiGrain grain,
    BiPeriod end,
    int count,
  ) => BiModuleSeriesProvider._(
    argument: (workspaceId, moduleId, grain, end, count),
    from: this,
  );

  @override
  String toString() => r'biModuleSeriesProvider';
}

/// #1923 C — the saved views, through their definer RPCs.

@ProviderFor(biViewRepository)
final biViewRepositoryProvider = BiViewRepositoryProvider._();

/// #1923 C — the saved views, through their definer RPCs.

final class BiViewRepositoryProvider
    extends
        $FunctionalProvider<
          BiViewRepository,
          BiViewRepository,
          BiViewRepository
        >
    with $Provider<BiViewRepository> {
  /// #1923 C — the saved views, through their definer RPCs.
  BiViewRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'biViewRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$biViewRepositoryHash();

  @$internal
  @override
  $ProviderElement<BiViewRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BiViewRepository create(Ref ref) {
    return biViewRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BiViewRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BiViewRepository>(value),
    );
  }
}

String _$biViewRepositoryHash() => r'46d52fab7110f761a6c7a74dd836ee34a9e01d78';

/// The reader's private views and the workspace's team views.

@ProviderFor(biViews)
final biViewsProvider = BiViewsFamily._();

/// The reader's private views and the workspace's team views.

final class BiViewsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<BiSavedView>>,
          List<BiSavedView>,
          FutureOr<List<BiSavedView>>
        >
    with
        $FutureModifier<List<BiSavedView>>,
        $FutureProvider<List<BiSavedView>> {
  /// The reader's private views and the workspace's team views.
  BiViewsProvider._({
    required BiViewsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'biViewsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$biViewsHash();

  @override
  String toString() {
    return r'biViewsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<BiSavedView>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<BiSavedView>> create(Ref ref) {
    final argument = this.argument as String;
    return biViews(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BiViewsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$biViewsHash() => r'37c4bb9e21f3db8620426b39f745a948f36bf6a3';

/// The reader's private views and the workspace's team views.

final class BiViewsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<BiSavedView>>, String> {
  BiViewsFamily._()
    : super(
        retry: null,
        name: r'biViewsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The reader's private views and the workspace's team views.

  BiViewsProvider call(String workspaceId) =>
      BiViewsProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'biViewsProvider';
}

@ProviderFor(biViewActions)
final biViewActionsProvider = BiViewActionsProvider._();

final class BiViewActionsProvider
    extends $FunctionalProvider<BiViewActions, BiViewActions, BiViewActions>
    with $Provider<BiViewActions> {
  BiViewActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'biViewActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$biViewActionsHash();

  @$internal
  @override
  $ProviderElement<BiViewActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BiViewActions create(Ref ref) {
    return biViewActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BiViewActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BiViewActions>(value),
    );
  }
}

String _$biViewActionsHash() => r'0e4e30edaf09fa66627b7a9fe222efa294b713eb';

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'overview_kpi_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(overviewKpiRepository)
final overviewKpiRepositoryProvider = OverviewKpiRepositoryProvider._();

final class OverviewKpiRepositoryProvider
    extends
        $FunctionalProvider<
          OverviewKpiRepository,
          OverviewKpiRepository,
          OverviewKpiRepository
        >
    with $Provider<OverviewKpiRepository> {
  OverviewKpiRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'overviewKpiRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$overviewKpiRepositoryHash();

  @$internal
  @override
  $ProviderElement<OverviewKpiRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OverviewKpiRepository create(Ref ref) {
    return overviewKpiRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OverviewKpiRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OverviewKpiRepository>(value),
    );
  }
}

String _$overviewKpiRepositoryHash() =>
    r'be5e93de0d8330c8e7ae67390d76437c635a228e';

/// One figure of [kpiId] for the whole months [fromMonth, toMonth].

@ProviderFor(overviewFigure)
final overviewFigureProvider = OverviewFigureFamily._();

/// One figure of [kpiId] for the whole months [fromMonth, toMonth].

final class OverviewFigureProvider
    extends
        $FunctionalProvider<
          AsyncValue<OverviewFigure>,
          OverviewFigure,
          FutureOr<OverviewFigure>
        >
    with $FutureModifier<OverviewFigure>, $FutureProvider<OverviewFigure> {
  /// One figure of [kpiId] for the whole months [fromMonth, toMonth].
  OverviewFigureProvider._({
    required OverviewFigureFamily super.from,
    required (String, String, String, String) super.argument,
  }) : super(
         retry: kpiRetry,
         name: r'overviewFigureProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$overviewFigureHash();

  @override
  String toString() {
    return r'overviewFigureProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<OverviewFigure> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<OverviewFigure> create(Ref ref) {
    final argument = this.argument as (String, String, String, String);
    return overviewFigure(
      ref,
      argument.$1,
      argument.$2,
      argument.$3,
      argument.$4,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is OverviewFigureProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$overviewFigureHash() => r'52b8697a85f3fac718e64d86e0428f4ebfc90b01';

/// One figure of [kpiId] for the whole months [fromMonth, toMonth].

final class OverviewFigureFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<OverviewFigure>,
          (String, String, String, String)
        > {
  OverviewFigureFamily._()
    : super(
        retry: kpiRetry,
        name: r'overviewFigureProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One figure of [kpiId] for the whole months [fromMonth, toMonth].

  OverviewFigureProvider call(
    String workspaceId,
    String kpiId,
    String fromMonth,
    String toMonth,
  ) => OverviewFigureProvider._(
    argument: (workspaceId, kpiId, fromMonth, toMonth),
    from: this,
  );

  @override
  String toString() => r'overviewFigureProvider';
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'default_period_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(defaultPeriodStore)
final defaultPeriodStoreProvider = DefaultPeriodStoreProvider._();

final class DefaultPeriodStoreProvider
    extends
        $FunctionalProvider<
          DefaultPeriodStore,
          DefaultPeriodStore,
          DefaultPeriodStore
        >
    with $Provider<DefaultPeriodStore> {
  DefaultPeriodStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'defaultPeriodStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$defaultPeriodStoreHash();

  @$internal
  @override
  $ProviderElement<DefaultPeriodStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DefaultPeriodStore create(Ref ref) {
    return defaultPeriodStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DefaultPeriodStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DefaultPeriodStore>(value),
    );
  }
}

String _$defaultPeriodStoreHash() =>
    r'c406fb55e4da72268abac651819c19e9a697198f';

/// The active workspace's stored default period, validated against what
/// the CURRENT booking configuration still offers — a preference saved
/// under half-days is silently ignored after the owner reconfigures to
/// a minute grid.

@ProviderFor(DefaultPeriod)
final defaultPeriodProvider = DefaultPeriodProvider._();

/// The active workspace's stored default period, validated against what
/// the CURRENT booking configuration still offers — a preference saved
/// under half-days is silently ignored after the owner reconfigures to
/// a minute grid.
final class DefaultPeriodProvider
    extends $AsyncNotifierProvider<DefaultPeriod, DefaultBookingPeriod?> {
  /// The active workspace's stored default period, validated against what
  /// the CURRENT booking configuration still offers — a preference saved
  /// under half-days is silently ignored after the owner reconfigures to
  /// a minute grid.
  DefaultPeriodProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'defaultPeriodProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$defaultPeriodHash();

  @$internal
  @override
  DefaultPeriod create() => DefaultPeriod();
}

String _$defaultPeriodHash() => r'88544dde4a53ebb9b69d6406270eda269bb8d1df';

/// The active workspace's stored default period, validated against what
/// the CURRENT booking configuration still offers — a preference saved
/// under half-days is silently ignored after the owner reconfigures to
/// a minute grid.

abstract class _$DefaultPeriod extends $AsyncNotifier<DefaultBookingPeriod?> {
  FutureOr<DefaultBookingPeriod?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<DefaultBookingPeriod?>, DefaultBookingPeriod?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<DefaultBookingPeriod?>,
                DefaultBookingPeriod?
              >,
              AsyncValue<DefaultBookingPeriod?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

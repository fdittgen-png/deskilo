// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'desk_navigation.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(deskRailCollapsedStore)
final deskRailCollapsedStoreProvider = DeskRailCollapsedStoreProvider._();

final class DeskRailCollapsedStoreProvider
    extends $FunctionalProvider<ShellFlagStore, ShellFlagStore, ShellFlagStore>
    with $Provider<ShellFlagStore> {
  DeskRailCollapsedStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deskRailCollapsedStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deskRailCollapsedStoreHash();

  @$internal
  @override
  $ProviderElement<ShellFlagStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ShellFlagStore create(Ref ref) {
    return deskRailCollapsedStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShellFlagStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShellFlagStore>(value),
    );
  }
}

String _$deskRailCollapsedStoreHash() =>
    r'2cf2a0f70a9bad928d7646a717f7b2eb5154cc0c';

/// Whether the person narrowed the desk's sidebar to the rail. Loading
/// reads as the sidebar: the view that names every destination.

@ProviderFor(DeskRailCollapsed)
final deskRailCollapsedProvider = DeskRailCollapsedProvider._();

/// Whether the person narrowed the desk's sidebar to the rail. Loading
/// reads as the sidebar: the view that names every destination.
final class DeskRailCollapsedProvider
    extends $AsyncNotifierProvider<DeskRailCollapsed, bool> {
  /// Whether the person narrowed the desk's sidebar to the rail. Loading
  /// reads as the sidebar: the view that names every destination.
  DeskRailCollapsedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deskRailCollapsedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deskRailCollapsedHash();

  @$internal
  @override
  DeskRailCollapsed create() => DeskRailCollapsed();
}

String _$deskRailCollapsedHash() => r'80a0f7baa2bee193b614fab64208c3bb6b6c2cbf';

/// Whether the person narrowed the desk's sidebar to the rail. Loading
/// reads as the sidebar: the view that names every destination.

abstract class _$DeskRailCollapsed extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

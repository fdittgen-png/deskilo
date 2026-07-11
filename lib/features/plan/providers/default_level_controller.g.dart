// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'default_level_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(defaultLevelStore)
final defaultLevelStoreProvider = DefaultLevelStoreProvider._();

final class DefaultLevelStoreProvider
    extends
        $FunctionalProvider<
          DefaultLevelStore,
          DefaultLevelStore,
          DefaultLevelStore
        >
    with $Provider<DefaultLevelStore> {
  DefaultLevelStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'defaultLevelStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$defaultLevelStoreHash();

  @$internal
  @override
  $ProviderElement<DefaultLevelStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DefaultLevelStore create(Ref ref) {
    return defaultLevelStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DefaultLevelStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DefaultLevelStore>(value),
    );
  }
}

String _$defaultLevelStoreHash() => r'f6ada5bd9127ee6078254a31fbcc7de742050baa';

/// The level shown on the Plan tab (#159): initially the stored default
/// of the active workspace when that level still exists, else the first
/// level (sort order). Selecting a level applies instantly and persists
/// it as the member's default for this workspace.

@ProviderFor(SelectedLevelId)
final selectedLevelIdProvider = SelectedLevelIdProvider._();

/// The level shown on the Plan tab (#159): initially the stored default
/// of the active workspace when that level still exists, else the first
/// level (sort order). Selecting a level applies instantly and persists
/// it as the member's default for this workspace.
final class SelectedLevelIdProvider
    extends $AsyncNotifierProvider<SelectedLevelId, String?> {
  /// The level shown on the Plan tab (#159): initially the stored default
  /// of the active workspace when that level still exists, else the first
  /// level (sort order). Selecting a level applies instantly and persists
  /// it as the member's default for this workspace.
  SelectedLevelIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedLevelIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedLevelIdHash();

  @$internal
  @override
  SelectedLevelId create() => SelectedLevelId();
}

String _$selectedLevelIdHash() => r'798c78f0c75e7b2ba18e5049bb3bba768b041afb';

/// The level shown on the Plan tab (#159): initially the stored default
/// of the active workspace when that level still exists, else the first
/// level (sort order). Selecting a level applies instantly and persists
/// it as the member's default for this workspace.

abstract class _$SelectedLevelId extends $AsyncNotifier<String?> {
  FutureOr<String?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, String?>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

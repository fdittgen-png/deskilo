// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(themeStore)
final themeStoreProvider = ThemeStoreProvider._();

final class ThemeStoreProvider
    extends $FunctionalProvider<ThemeStore, ThemeStore, ThemeStore>
    with $Provider<ThemeStore> {
  ThemeStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeStoreHash();

  @$internal
  @override
  $ProviderElement<ThemeStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ThemeStore create(Ref ref) {
    return themeStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeStore>(value),
    );
  }
}

String _$themeStoreHash() => r'ba3c9f825a7fdddf111964e4a622fc015aac3058';

/// The user's theme override; null means "follow the system brightness".
/// Feeding this into `MaterialApp.themeMode` applies a change instantly,
/// no restart needed.

@ProviderFor(ThemeController)
final themeControllerProvider = ThemeControllerProvider._();

/// The user's theme override; null means "follow the system brightness".
/// Feeding this into `MaterialApp.themeMode` applies a change instantly,
/// no restart needed.
final class ThemeControllerProvider
    extends $AsyncNotifierProvider<ThemeController, ThemeMode?> {
  /// The user's theme override; null means "follow the system brightness".
  /// Feeding this into `MaterialApp.themeMode` applies a change instantly,
  /// no restart needed.
  ThemeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeControllerHash();

  @$internal
  @override
  ThemeController create() => ThemeController();
}

String _$themeControllerHash() => r'82b891338c25269964465225e668a922c1893e05';

/// The user's theme override; null means "follow the system brightness".
/// Feeding this into `MaterialApp.themeMode` applies a change instantly,
/// no restart needed.

abstract class _$ThemeController extends $AsyncNotifier<ThemeMode?> {
  FutureOr<ThemeMode?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ThemeMode?>, ThemeMode?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ThemeMode?>, ThemeMode?>,
              AsyncValue<ThemeMode?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'navigation_style.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(navigationStyleStore)
final navigationStyleStoreProvider = NavigationStyleStoreProvider._();

final class NavigationStyleStoreProvider
    extends
        $FunctionalProvider<
          NavigationStyleStore,
          NavigationStyleStore,
          NavigationStyleStore
        >
    with $Provider<NavigationStyleStore> {
  NavigationStyleStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'navigationStyleStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$navigationStyleStoreHash();

  @$internal
  @override
  $ProviderElement<NavigationStyleStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NavigationStyleStore create(Ref ref) {
    return navigationStyleStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NavigationStyleStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NavigationStyleStore>(value),
    );
  }
}

String _$navigationStyleStoreHash() =>
    r'fe0e87261733c28f7297b580db656d339e165c9e';

/// The platform the app runs on: the web has the menu and ONLY the
/// menu — a browser window has the width a phone lacks and none of the
/// thumb-reach the bar was built for — so the choice never appears
/// there. Tests override it to run "as the web".

@ProviderFor(platformIsWeb)
final platformIsWebProvider = PlatformIsWebProvider._();

/// The platform the app runs on: the web has the menu and ONLY the
/// menu — a browser window has the width a phone lacks and none of the
/// thumb-reach the bar was built for — so the choice never appears
/// there. Tests override it to run "as the web".

final class PlatformIsWebProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// The platform the app runs on: the web has the menu and ONLY the
  /// menu — a browser window has the width a phone lacks and none of the
  /// thumb-reach the bar was built for — so the choice never appears
  /// there. Tests override it to run "as the web".
  PlatformIsWebProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'platformIsWebProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$platformIsWebHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return platformIsWeb(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$platformIsWebHash() => r'bf1d5b48bcda84a482d4e54900fa3b94f9a9e377';

/// The user's navigation override; null means "what this platform gets
/// by default" (the bar on native, the menu on the web). Applied
/// instantly — the shell watches it.

@ProviderFor(NavigationStyleController)
final navigationStyleControllerProvider = NavigationStyleControllerProvider._();

/// The user's navigation override; null means "what this platform gets
/// by default" (the bar on native, the menu on the web). Applied
/// instantly — the shell watches it.
final class NavigationStyleControllerProvider
    extends
        $AsyncNotifierProvider<NavigationStyleController, NavigationStyle?> {
  /// The user's navigation override; null means "what this platform gets
  /// by default" (the bar on native, the menu on the web). Applied
  /// instantly — the shell watches it.
  NavigationStyleControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'navigationStyleControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$navigationStyleControllerHash();

  @$internal
  @override
  NavigationStyleController create() => NavigationStyleController();
}

String _$navigationStyleControllerHash() =>
    r'95b1d0791844a5e568d33140c83fc96c8a8c468d';

/// The user's navigation override; null means "what this platform gets
/// by default" (the bar on native, the menu on the web). Applied
/// instantly — the shell watches it.

abstract class _$NavigationStyleController
    extends $AsyncNotifier<NavigationStyle?> {
  FutureOr<NavigationStyle?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<NavigationStyle?>, NavigationStyle?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<NavigationStyle?>, NavigationStyle?>,
              AsyncValue<NavigationStyle?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

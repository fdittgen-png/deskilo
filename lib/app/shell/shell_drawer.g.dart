// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shell_drawer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #2414 — the navigation a device that never chose gets. "Everyday
/// only" is a member whose permissions in this space are the everyday
/// six at most; outside a space (Me), one who runs no space at all.

@ProviderFor(navigationDefault)
final navigationDefaultProvider = NavigationDefaultProvider._();

/// #2414 — the navigation a device that never chose gets. "Everyday
/// only" is a member whose permissions in this space are the everyday
/// six at most; outside a space (Me), one who runs no space at all.

final class NavigationDefaultProvider
    extends
        $FunctionalProvider<NavigationStyle, NavigationStyle, NavigationStyle>
    with $Provider<NavigationStyle> {
  /// #2414 — the navigation a device that never chose gets. "Everyday
  /// only" is a member whose permissions in this space are the everyday
  /// six at most; outside a space (Me), one who runs no space at all.
  NavigationDefaultProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'navigationDefaultProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$navigationDefaultHash();

  @$internal
  @override
  $ProviderElement<NavigationStyle> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NavigationStyle create(Ref ref) {
    return navigationDefault(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NavigationStyle value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NavigationStyle>(value),
    );
  }
}

String _$navigationDefaultHash() => r'db0d4bbf54ca2aaaf0130f12f1e7613b1bb98940';

/// Whether the shell navigates through the drawer — the web build
/// always, native per the user's choice (#969) or the device's default
/// (#2414), and tests that ask for it.

@ProviderFor(webShell)
final webShellProvider = WebShellProvider._();

/// Whether the shell navigates through the drawer — the web build
/// always, native per the user's choice (#969) or the device's default
/// (#2414), and tests that ask for it.

final class WebShellProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the shell navigates through the drawer — the web build
  /// always, native per the user's choice (#969) or the device's default
  /// (#2414), and tests that ask for it.
  WebShellProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'webShellProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$webShellHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return webShell(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$webShellHash() => r'f0067318049620bfddf9a057d0eb85d410465142';

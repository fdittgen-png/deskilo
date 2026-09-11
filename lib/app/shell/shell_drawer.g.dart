// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shell_drawer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the shell navigates through the drawer — the web build
/// always, native when the user chose the menu (#969), and tests that
/// ask for it.

@ProviderFor(webShell)
final webShellProvider = WebShellProvider._();

/// Whether the shell navigates through the drawer — the web build
/// always, native when the user chose the menu (#969), and tests that
/// ask for it.

final class WebShellProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the shell navigates through the drawer — the web build
  /// always, native when the user chose the menu (#969), and tests that
  /// ask for it.
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

String _$webShellHash() => r'e6fc6cee57b115a26729884ff39b8bc5cee79f64';

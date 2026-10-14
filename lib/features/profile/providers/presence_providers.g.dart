// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'presence_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Starts the foreground last-seen heartbeat (#223). Watched once from
/// DeskiloApp, like the push bootstrap is watched from the shell.
///
/// Signed out, the provider builds to nothing — no timer exists at all.
/// Signing in/out rebuilds it (the same authStateProvider gate the
/// workspace providers use); while built, an [AppLifecycleListener]
/// pauses the heartbeat whenever the app leaves the resumed state.

@ProviderFor(presenceBootstrap)
final presenceBootstrapProvider = PresenceBootstrapProvider._();

/// Starts the foreground last-seen heartbeat (#223). Watched once from
/// DeskiloApp, like the push bootstrap is watched from the shell.
///
/// Signed out, the provider builds to nothing — no timer exists at all.
/// Signing in/out rebuilds it (the same authStateProvider gate the
/// workspace providers use); while built, an [AppLifecycleListener]
/// pauses the heartbeat whenever the app leaves the resumed state.

final class PresenceBootstrapProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Starts the foreground last-seen heartbeat (#223). Watched once from
  /// DeskiloApp, like the push bootstrap is watched from the shell.
  ///
  /// Signed out, the provider builds to nothing — no timer exists at all.
  /// Signing in/out rebuilds it (the same authStateProvider gate the
  /// workspace providers use); while built, an [AppLifecycleListener]
  /// pauses the heartbeat whenever the app leaves the resumed state.
  PresenceBootstrapProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'presenceBootstrapProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$presenceBootstrapHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return presenceBootstrap(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$presenceBootstrapHash() => r'eff474acb663f61ef719975e2c3cf36c6b78125d';

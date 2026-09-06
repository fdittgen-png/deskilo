// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'instance_bundle_asset.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// How the wizard gets its bundle — the asset, or a small one in tests.

@ProviderFor(instanceBundleLoader)
final instanceBundleLoaderProvider = InstanceBundleLoaderProvider._();

/// How the wizard gets its bundle — the asset, or a small one in tests.

final class InstanceBundleLoaderProvider
    extends
        $FunctionalProvider<
          Future<InstanceBundle> Function(),
          Future<InstanceBundle> Function(),
          Future<InstanceBundle> Function()
        >
    with $Provider<Future<InstanceBundle> Function()> {
  /// How the wizard gets its bundle — the asset, or a small one in tests.
  InstanceBundleLoaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'instanceBundleLoaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$instanceBundleLoaderHash();

  @$internal
  @override
  $ProviderElement<Future<InstanceBundle> Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Future<InstanceBundle> Function() create(Ref ref) {
    return instanceBundleLoader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Future<InstanceBundle> Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Future<InstanceBundle> Function()>(
        value,
      ),
    );
  }
}

String _$instanceBundleLoaderHash() =>
    r'b4bbd5e9471ff8c5b8347def4a57147ecf899107';

/// How the wizard talks to Supabase for a given access token — the real
/// API, or a fake in tests. The token lives in the wizard's state only.

@ProviderFor(supabaseManagementFactory)
final supabaseManagementFactoryProvider = SupabaseManagementFactoryProvider._();

/// How the wizard talks to Supabase for a given access token — the real
/// API, or a fake in tests. The token lives in the wizard's state only.

final class SupabaseManagementFactoryProvider
    extends
        $FunctionalProvider<
          SupabaseManagement Function(String accessToken),
          SupabaseManagement Function(String accessToken),
          SupabaseManagement Function(String accessToken)
        >
    with $Provider<SupabaseManagement Function(String accessToken)> {
  /// How the wizard talks to Supabase for a given access token — the real
  /// API, or a fake in tests. The token lives in the wizard's state only.
  SupabaseManagementFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supabaseManagementFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supabaseManagementFactoryHash();

  @$internal
  @override
  $ProviderElement<SupabaseManagement Function(String accessToken)>
  $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  SupabaseManagement Function(String accessToken) create(Ref ref) {
    return supabaseManagementFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
    SupabaseManagement Function(String accessToken) value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<SupabaseManagement Function(String accessToken)>(
            value,
          ),
    );
  }
}

String _$supabaseManagementFactoryHash() =>
    r'938ee27ef80d5596031793011599613ea46b6472';

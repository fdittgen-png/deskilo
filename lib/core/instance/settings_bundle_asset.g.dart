// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_bundle_asset.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The registry as the app ships it (#2484): keys, types, bounds and
/// defaults, no stored values. What a build with no reachable server
/// stands on. A canned list in tests.

@ProviderFor(settingsBundleLoader)
final settingsBundleLoaderProvider = SettingsBundleLoaderProvider._();

/// The registry as the app ships it (#2484): keys, types, bounds and
/// defaults, no stored values. What a build with no reachable server
/// stands on. A canned list in tests.

final class SettingsBundleLoaderProvider
    extends
        $FunctionalProvider<
          Future<List<SettingDefinition>> Function(),
          Future<List<SettingDefinition>> Function(),
          Future<List<SettingDefinition>> Function()
        >
    with $Provider<Future<List<SettingDefinition>> Function()> {
  /// The registry as the app ships it (#2484): keys, types, bounds and
  /// defaults, no stored values. What a build with no reachable server
  /// stands on. A canned list in tests.
  SettingsBundleLoaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsBundleLoaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsBundleLoaderHash();

  @$internal
  @override
  $ProviderElement<Future<List<SettingDefinition>> Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Future<List<SettingDefinition>> Function() create(Ref ref) {
    return settingsBundleLoader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Future<List<SettingDefinition>> Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<Future<List<SettingDefinition>> Function()>(value),
    );
  }
}

String _$settingsBundleLoaderHash() =>
    r'c915f80671b281c54d54f0fe85c6e6db3708b33f';

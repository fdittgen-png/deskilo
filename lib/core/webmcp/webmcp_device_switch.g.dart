// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webmcp_device_switch.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(webMcpSwitchStore)
final webMcpSwitchStoreProvider = WebMcpSwitchStoreProvider._();

final class WebMcpSwitchStoreProvider
    extends
        $FunctionalProvider<
          WebMcpSwitchStore,
          WebMcpSwitchStore,
          WebMcpSwitchStore
        >
    with $Provider<WebMcpSwitchStore> {
  WebMcpSwitchStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'webMcpSwitchStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$webMcpSwitchStoreHash();

  @$internal
  @override
  $ProviderElement<WebMcpSwitchStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WebMcpSwitchStore create(Ref ref) {
    return webMcpSwitchStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WebMcpSwitchStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WebMcpSwitchStore>(value),
    );
  }
}

String _$webMcpSwitchStoreHash() => r'f8df99d3df95928e34c6911b53b7fb7626fa6a8e';

/// True when the person let in-browser assistants use this page's tools on
/// this device.

@ProviderFor(WebMcpDeviceSwitch)
final webMcpDeviceSwitchProvider = WebMcpDeviceSwitchProvider._();

/// True when the person let in-browser assistants use this page's tools on
/// this device.
final class WebMcpDeviceSwitchProvider
    extends $AsyncNotifierProvider<WebMcpDeviceSwitch, bool> {
  /// True when the person let in-browser assistants use this page's tools on
  /// this device.
  WebMcpDeviceSwitchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'webMcpDeviceSwitchProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$webMcpDeviceSwitchHash();

  @$internal
  @override
  WebMcpDeviceSwitch create() => WebMcpDeviceSwitch();
}

String _$webMcpDeviceSwitchHash() =>
    r'ef4c3b7b74902ad91f0a2d1169f2c8c70e0afcd5';

/// True when the person let in-browser assistants use this page's tools on
/// this device.

abstract class _$WebMcpDeviceSwitch extends $AsyncNotifier<bool> {
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

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kiosk_device_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #3675 — the business's enrolled kiosks.

@ProviderFor(kioskDeviceRepository)
final kioskDeviceRepositoryProvider = KioskDeviceRepositoryProvider._();

/// #3675 — the business's enrolled kiosks.

final class KioskDeviceRepositoryProvider
    extends
        $FunctionalProvider<
          KioskDeviceRepository,
          KioskDeviceRepository,
          KioskDeviceRepository
        >
    with $Provider<KioskDeviceRepository> {
  /// #3675 — the business's enrolled kiosks.
  KioskDeviceRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'kioskDeviceRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$kioskDeviceRepositoryHash();

  @$internal
  @override
  $ProviderElement<KioskDeviceRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  KioskDeviceRepository create(Ref ref) {
    return kioskDeviceRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(KioskDeviceRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<KioskDeviceRepository>(value),
    );
  }
}

String _$kioskDeviceRepositoryHash() =>
    r'd6bf6adfaa83765b1665ecc4ff9714b2b8cc8527';

/// The devices of [workspaceId], newest first.

@ProviderFor(kioskDevices)
final kioskDevicesProvider = KioskDevicesFamily._();

/// The devices of [workspaceId], newest first.

final class KioskDevicesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<KioskDevice>>,
          List<KioskDevice>,
          FutureOr<List<KioskDevice>>
        >
    with
        $FutureModifier<List<KioskDevice>>,
        $FutureProvider<List<KioskDevice>> {
  /// The devices of [workspaceId], newest first.
  KioskDevicesProvider._({
    required KioskDevicesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'kioskDevicesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$kioskDevicesHash();

  @override
  String toString() {
    return r'kioskDevicesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<KioskDevice>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<KioskDevice>> create(Ref ref) {
    final argument = this.argument as String;
    return kioskDevices(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is KioskDevicesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$kioskDevicesHash() => r'7deddc629cd412d8115296afbd139c5074642e38';

/// The devices of [workspaceId], newest first.

final class KioskDevicesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<KioskDevice>>, String> {
  KioskDevicesFamily._()
    : super(
        retry: null,
        name: r'kioskDevicesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The devices of [workspaceId], newest first.

  KioskDevicesProvider call(String workspaceId) =>
      KioskDevicesProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'kioskDevicesProvider';
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'front_camera.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(frontCameraStore)
final frontCameraStoreProvider = FrontCameraStoreProvider._();

final class FrontCameraStoreProvider
    extends
        $FunctionalProvider<
          FrontCameraStore,
          FrontCameraStore,
          FrontCameraStore
        >
    with $Provider<FrontCameraStore> {
  FrontCameraStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'frontCameraStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$frontCameraStoreHash();

  @$internal
  @override
  $ProviderElement<FrontCameraStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FrontCameraStore create(Ref ref) {
    return frontCameraStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FrontCameraStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FrontCameraStore>(value),
    );
  }
}

String _$frontCameraStoreHash() => r'b40acd052050ba4745e0e52d802a85b74cdb941c';

/// Whether badge scanning uses the FRONT (screen-side) camera — the
/// default: a wall-mounted kiosk tablet has its back camera against the
/// wall, so the badge is held up to the screen. Off = back camera, for
/// handheld devices. Local device preference (camera is hardware).

@ProviderFor(FrontCameraScan)
final frontCameraScanProvider = FrontCameraScanProvider._();

/// Whether badge scanning uses the FRONT (screen-side) camera — the
/// default: a wall-mounted kiosk tablet has its back camera against the
/// wall, so the badge is held up to the screen. Off = back camera, for
/// handheld devices. Local device preference (camera is hardware).
final class FrontCameraScanProvider
    extends $AsyncNotifierProvider<FrontCameraScan, bool> {
  /// Whether badge scanning uses the FRONT (screen-side) camera — the
  /// default: a wall-mounted kiosk tablet has its back camera against the
  /// wall, so the badge is held up to the screen. Off = back camera, for
  /// handheld devices. Local device preference (camera is hardware).
  FrontCameraScanProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'frontCameraScanProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$frontCameraScanHash();

  @$internal
  @override
  FrontCameraScan create() => FrontCameraScan();
}

String _$frontCameraScanHash() => r'd5d193925f46e0b2b95562912fad8144ea1d0dba';

/// Whether badge scanning uses the FRONT (screen-side) camera — the
/// default: a wall-mounted kiosk tablet has its back camera against the
/// wall, so the badge is held up to the screen. Off = back camera, for
/// handheld devices. Local device preference (camera is hardware).

abstract class _$FrontCameraScan extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

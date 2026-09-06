// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'demo_mode.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(demoModeStore)
final demoModeStoreProvider = DemoModeStoreProvider._();

final class DemoModeStoreProvider
    extends $FunctionalProvider<DemoModeStore, DemoModeStore, DemoModeStore>
    with $Provider<DemoModeStore> {
  DemoModeStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'demoModeStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$demoModeStoreHash();

  @$internal
  @override
  $ProviderElement<DemoModeStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DemoModeStore create(Ref ref) {
    return demoModeStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DemoModeStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DemoModeStore>(value),
    );
  }
}

String _$demoModeStoreHash() => r'9d4867cfed943a8fbe61096bcc255eb24a9c5d96';

@ProviderFor(DemoModeController)
final demoModeControllerProvider = DemoModeControllerProvider._();

final class DemoModeControllerProvider
    extends $AsyncNotifierProvider<DemoModeController, bool> {
  DemoModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'demoModeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$demoModeControllerHash();

  @$internal
  @override
  DemoModeController create() => DemoModeController();
}

String _$demoModeControllerHash() =>
    r'b8c0c2db09b4671b0874fab8c2c2907efd306a98';

abstract class _$DemoModeController extends $AsyncNotifier<bool> {
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

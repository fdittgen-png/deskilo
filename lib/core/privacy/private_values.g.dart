// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'private_values.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(privateValuesStore)
final privateValuesStoreProvider = PrivateValuesStoreProvider._();

final class PrivateValuesStoreProvider
    extends
        $FunctionalProvider<
          PrivateValuesStore,
          PrivateValuesStore,
          PrivateValuesStore
        >
    with $Provider<PrivateValuesStore> {
  PrivateValuesStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'privateValuesStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$privateValuesStoreHash();

  @$internal
  @override
  $ProviderElement<PrivateValuesStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PrivateValuesStore create(Ref ref) {
    return privateValuesStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PrivateValuesStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PrivateValuesStore>(value),
    );
  }
}

String _$privateValuesStoreHash() =>
    r'ed789adfc16b57e1a2686f7f17d581e2504551a7';

/// The choice stored on this device; null when none was made here.

@ProviderFor(PrivateValuesDevice)
final privateValuesDeviceProvider = PrivateValuesDeviceProvider._();

/// The choice stored on this device; null when none was made here.
final class PrivateValuesDeviceProvider
    extends $AsyncNotifierProvider<PrivateValuesDevice, String?> {
  /// The choice stored on this device; null when none was made here.
  PrivateValuesDeviceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'privateValuesDeviceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$privateValuesDeviceHash();

  @$internal
  @override
  PrivateValuesDevice create() => PrivateValuesDevice();
}

String _$privateValuesDeviceHash() =>
    r'515057deec8f08eca6c5986520e17c3edb895a12';

/// The choice stored on this device; null when none was made here.

abstract class _$PrivateValuesDevice extends $AsyncNotifier<String?> {
  FutureOr<String?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, String?>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(privateValuesPolicy)
final privateValuesPolicyProvider = PrivateValuesPolicyProvider._();

final class PrivateValuesPolicyProvider
    extends
        $FunctionalProvider<
          PrivateValuesPolicy,
          PrivateValuesPolicy,
          PrivateValuesPolicy
        >
    with $Provider<PrivateValuesPolicy> {
  PrivateValuesPolicyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'privateValuesPolicyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$privateValuesPolicyHash();

  @$internal
  @override
  $ProviderElement<PrivateValuesPolicy> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PrivateValuesPolicy create(Ref ref) {
    return privateValuesPolicy(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PrivateValuesPolicy value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PrivateValuesPolicy>(value),
    );
  }
}

String _$privateValuesPolicyHash() =>
    r'5b8152e2f4efe5e2bdd27e14c7c03cfb6bd5182a';

/// True while a private value starts masked.

@ProviderFor(privateValuesMasked)
final privateValuesMaskedProvider = PrivateValuesMaskedProvider._();

/// True while a private value starts masked.

final class PrivateValuesMaskedProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// True while a private value starts masked.
  PrivateValuesMaskedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'privateValuesMaskedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$privateValuesMaskedHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return privateValuesMasked(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$privateValuesMaskedHash() =>
    r'3fc6ff80f8d3b42fc56bac28191ba3573e4c8a0a';

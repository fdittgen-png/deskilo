// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_opt_out.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pushOptOutStore)
final pushOptOutStoreProvider = PushOptOutStoreProvider._();

final class PushOptOutStoreProvider
    extends
        $FunctionalProvider<PushOptOutStore, PushOptOutStore, PushOptOutStore>
    with $Provider<PushOptOutStore> {
  PushOptOutStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushOptOutStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushOptOutStoreHash();

  @$internal
  @override
  $ProviderElement<PushOptOutStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PushOptOutStore create(Ref ref) {
    return pushOptOutStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushOptOutStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushOptOutStore>(value),
    );
  }
}

String _$pushOptOutStoreHash() => r'b672670bba2cebd60ad695aea948b29d4a31650d';

/// True when the person turned push delivery off on this device.

@ProviderFor(PushOptedOut)
final pushOptedOutProvider = PushOptedOutProvider._();

/// True when the person turned push delivery off on this device.
final class PushOptedOutProvider
    extends $AsyncNotifierProvider<PushOptedOut, bool> {
  /// True when the person turned push delivery off on this device.
  PushOptedOutProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushOptedOutProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushOptedOutHash();

  @$internal
  @override
  PushOptedOut create() => PushOptedOut();
}

String _$pushOptedOutHash() => r'287093a880da184f7b8cd2f040e5977b3c3ee39c';

/// True when the person turned push delivery off on this device.

abstract class _$PushOptedOut extends $AsyncNotifier<bool> {
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

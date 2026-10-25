// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resume_place_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(resumePlaceStore)
final resumePlaceStoreProvider = ResumePlaceStoreProvider._();

final class ResumePlaceStoreProvider
    extends
        $FunctionalProvider<
          ResumePlaceStore,
          ResumePlaceStore,
          ResumePlaceStore
        >
    with $Provider<ResumePlaceStore> {
  ResumePlaceStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'resumePlaceStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$resumePlaceStoreHash();

  @$internal
  @override
  $ProviderElement<ResumePlaceStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ResumePlaceStore create(Ref ref) {
    return resumePlaceStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ResumePlaceStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ResumePlaceStore>(value),
    );
  }
}

String _$resumePlaceStoreHash() => r'b40b770d2bed87d28b4e5455d9da7587fdcc877f';

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entry_intent_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(entryIntentStore)
final entryIntentStoreProvider = EntryIntentStoreProvider._();

final class EntryIntentStoreProvider
    extends
        $FunctionalProvider<
          EntryIntentStore,
          EntryIntentStore,
          EntryIntentStore
        >
    with $Provider<EntryIntentStore> {
  EntryIntentStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'entryIntentStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$entryIntentStoreHash();

  @$internal
  @override
  $ProviderElement<EntryIntentStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EntryIntentStore create(Ref ref) {
    return entryIntentStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EntryIntentStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EntryIntentStore>(value),
    );
  }
}

String _$entryIntentStoreHash() => r'2e512986f8ae478c178787d26204331052792a5e';

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_seen_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(noteSeenStore)
final noteSeenStoreProvider = NoteSeenStoreProvider._();

final class NoteSeenStoreProvider
    extends $FunctionalProvider<NoteSeenStore, NoteSeenStore, NoteSeenStore>
    with $Provider<NoteSeenStore> {
  NoteSeenStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'noteSeenStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$noteSeenStoreHash();

  @$internal
  @override
  $ProviderElement<NoteSeenStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NoteSeenStore create(Ref ref) {
    return noteSeenStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NoteSeenStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NoteSeenStore>(value),
    );
  }
}

String _$noteSeenStoreHash() => r'8c49e2faca35546221b74c5f5d2c1c5144a2280f';

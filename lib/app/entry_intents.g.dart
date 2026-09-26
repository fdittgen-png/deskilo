// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entry_intents.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The current continuation, or null. Kept alive: the router reads it on
/// every redirect and the value must not vanish between two.

@ProviderFor(EntryIntents)
final entryIntentsProvider = EntryIntentsProvider._();

/// The current continuation, or null. Kept alive: the router reads it on
/// every redirect and the value must not vanish between two.
final class EntryIntentsProvider
    extends $NotifierProvider<EntryIntents, EntryIntent?> {
  /// The current continuation, or null. Kept alive: the router reads it on
  /// every redirect and the value must not vanish between two.
  EntryIntentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'entryIntentsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$entryIntentsHash();

  @$internal
  @override
  EntryIntents create() => EntryIntents();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EntryIntent? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EntryIntent?>(value),
    );
  }
}

String _$entryIntentsHash() => r'b751ab42f7747824e087f36fe0089618c6a32f59';

/// The current continuation, or null. Kept alive: the router reads it on
/// every redirect and the value must not vanish between two.

abstract class _$EntryIntents extends $Notifier<EntryIntent?> {
  EntryIntent? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<EntryIntent?, EntryIntent?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<EntryIntent?, EntryIntent?>,
              EntryIntent?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

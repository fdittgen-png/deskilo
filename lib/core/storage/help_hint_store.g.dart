// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'help_hint_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(helpHintStore)
final helpHintStoreProvider = HelpHintStoreProvider._();

final class HelpHintStoreProvider
    extends $FunctionalProvider<HelpHintStore, HelpHintStore, HelpHintStore>
    with $Provider<HelpHintStore> {
  HelpHintStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'helpHintStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$helpHintStoreHash();

  @$internal
  @override
  $ProviderElement<HelpHintStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HelpHintStore create(Ref ref) {
    return helpHintStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HelpHintStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HelpHintStore>(value),
    );
  }
}

String _$helpHintStoreHash() => r'36cf3e659ab938badcb5242f67bc83d2705f13f7';

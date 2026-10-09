// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'space_attention_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(spaceAttentionCounts)
final spaceAttentionCountsProvider = SpaceAttentionCountsProvider._();

final class SpaceAttentionCountsProvider
    extends
        $FunctionalProvider<
          Map<String, int>,
          Map<String, int>,
          Map<String, int>
        >
    with $Provider<Map<String, int>> {
  SpaceAttentionCountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'spaceAttentionCountsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$spaceAttentionCountsHash();

  @$internal
  @override
  $ProviderElement<Map<String, int>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Map<String, int> create(Ref ref) {
    return spaceAttentionCounts(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, int>>(value),
    );
  }
}

String _$spaceAttentionCountsHash() =>
    r'4f98a76b17e7ab25169cdd0d25a4c333c28c9e3b';

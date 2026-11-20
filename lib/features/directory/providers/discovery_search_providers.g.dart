// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discovery_search_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DiscoverySearch)
final discoverySearchProvider = DiscoverySearchProvider._();

final class DiscoverySearchProvider
    extends $NotifierProvider<DiscoverySearch, DiscoverySearchState> {
  DiscoverySearchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'discoverySearchProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$discoverySearchHash();

  @$internal
  @override
  DiscoverySearch create() => DiscoverySearch();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DiscoverySearchState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DiscoverySearchState>(value),
    );
  }
}

String _$discoverySearchHash() => r'edbeccc302711b03a8233eb1c425fa8274c6af46';

abstract class _$DiscoverySearch extends $Notifier<DiscoverySearchState> {
  DiscoverySearchState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DiscoverySearchState, DiscoverySearchState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DiscoverySearchState, DiscoverySearchState>,
              DiscoverySearchState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discovery_listing_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// What discovery has loaded for [query]: the directory's first page of
/// sources and the first page of each, then whatever the person asks for
/// more of. A new query is a new listing; an answer that arrives after its
/// listing was left is dropped, so it never replaces a newer one.

@ProviderFor(DiscoveryListing)
final discoveryListingProvider = DiscoveryListingFamily._();

/// What discovery has loaded for [query]: the directory's first page of
/// sources and the first page of each, then whatever the person asks for
/// more of. A new query is a new listing; an answer that arrives after its
/// listing was left is dropped, so it never replaces a newer one.
final class DiscoveryListingProvider
    extends $AsyncNotifierProvider<DiscoveryListing, DiscoveryResults> {
  /// What discovery has loaded for [query]: the directory's first page of
  /// sources and the first page of each, then whatever the person asks for
  /// more of. A new query is a new listing; an answer that arrives after its
  /// listing was left is dropped, so it never replaces a newer one.
  DiscoveryListingProvider._({
    required DiscoveryListingFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'discoveryListingProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$discoveryListingHash();

  @override
  String toString() {
    return r'discoveryListingProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  DiscoveryListing create() => DiscoveryListing();

  @override
  bool operator ==(Object other) {
    return other is DiscoveryListingProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$discoveryListingHash() => r'9f933f4cdb1e1073eae4953b54ff37d8fe70963f';

/// What discovery has loaded for [query]: the directory's first page of
/// sources and the first page of each, then whatever the person asks for
/// more of. A new query is a new listing; an answer that arrives after its
/// listing was left is dropped, so it never replaces a newer one.

final class DiscoveryListingFamily extends $Family
    with
        $ClassFamilyOverride<
          DiscoveryListing,
          AsyncValue<DiscoveryResults>,
          DiscoveryResults,
          FutureOr<DiscoveryResults>,
          String
        > {
  DiscoveryListingFamily._()
    : super(
        retry: _noRetry,
        name: r'discoveryListingProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// What discovery has loaded for [query]: the directory's first page of
  /// sources and the first page of each, then whatever the person asks for
  /// more of. A new query is a new listing; an answer that arrives after its
  /// listing was left is dropped, so it never replaces a newer one.

  DiscoveryListingProvider call(String query) =>
      DiscoveryListingProvider._(argument: query, from: this);

  @override
  String toString() => r'discoveryListingProvider';
}

/// What discovery has loaded for [query]: the directory's first page of
/// sources and the first page of each, then whatever the person asks for
/// more of. A new query is a new listing; an answer that arrives after its
/// listing was left is dropped, so it never replaces a newer one.

abstract class _$DiscoveryListing extends $AsyncNotifier<DiscoveryResults> {
  late final _$args = ref.$arg as String;
  String get query => _$args;

  FutureOr<DiscoveryResults> build(String query);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<DiscoveryResults>, DiscoveryResults>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<DiscoveryResults>, DiscoveryResults>,
              AsyncValue<DiscoveryResults>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

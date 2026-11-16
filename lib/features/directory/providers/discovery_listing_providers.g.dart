// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discovery_listing_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// What discovery has loaded for [filter]: the directory's first page of
/// sources and the first page of each, then whatever the person asks for
/// more of. A new query or kind is a new listing; an answer that arrives
/// after its listing was left is dropped, so it never replaces a newer one.

@ProviderFor(DiscoveryListing)
final discoveryListingProvider = DiscoveryListingFamily._();

/// What discovery has loaded for [filter]: the directory's first page of
/// sources and the first page of each, then whatever the person asks for
/// more of. A new query or kind is a new listing; an answer that arrives
/// after its listing was left is dropped, so it never replaces a newer one.
final class DiscoveryListingProvider
    extends $AsyncNotifierProvider<DiscoveryListing, DiscoveryResults> {
  /// What discovery has loaded for [filter]: the directory's first page of
  /// sources and the first page of each, then whatever the person asks for
  /// more of. A new query or kind is a new listing; an answer that arrives
  /// after its listing was left is dropped, so it never replaces a newer one.
  DiscoveryListingProvider._({
    required DiscoveryListingFamily super.from,
    required DiscoveryFilter super.argument,
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

String _$discoveryListingHash() => r'e545a33effccb6646ca91033411ea251b7b70b38';

/// What discovery has loaded for [filter]: the directory's first page of
/// sources and the first page of each, then whatever the person asks for
/// more of. A new query or kind is a new listing; an answer that arrives
/// after its listing was left is dropped, so it never replaces a newer one.

final class DiscoveryListingFamily extends $Family
    with
        $ClassFamilyOverride<
          DiscoveryListing,
          AsyncValue<DiscoveryResults>,
          DiscoveryResults,
          FutureOr<DiscoveryResults>,
          DiscoveryFilter
        > {
  DiscoveryListingFamily._()
    : super(
        retry: _noRetry,
        name: r'discoveryListingProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// What discovery has loaded for [filter]: the directory's first page of
  /// sources and the first page of each, then whatever the person asks for
  /// more of. A new query or kind is a new listing; an answer that arrives
  /// after its listing was left is dropped, so it never replaces a newer one.

  DiscoveryListingProvider call(DiscoveryFilter filter) =>
      DiscoveryListingProvider._(argument: filter, from: this);

  @override
  String toString() => r'discoveryListingProvider';
}

/// What discovery has loaded for [filter]: the directory's first page of
/// sources and the first page of each, then whatever the person asks for
/// more of. A new query or kind is a new listing; an answer that arrives
/// after its listing was left is dropped, so it never replaces a newer one.

abstract class _$DiscoveryListing extends $AsyncNotifier<DiscoveryResults> {
  late final _$args = ref.$arg as DiscoveryFilter;
  DiscoveryFilter get filter => _$args;

  FutureOr<DiscoveryResults> build(DiscoveryFilter filter);
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

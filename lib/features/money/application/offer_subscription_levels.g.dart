// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offer_subscription_levels.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The pricing step's write of the offered levels.

@ProviderFor(offerSubscriptionLevels)
final offerSubscriptionLevelsProvider = OfferSubscriptionLevelsProvider._();

/// The pricing step's write of the offered levels.

final class OfferSubscriptionLevelsProvider
    extends
        $FunctionalProvider<
          OfferSubscriptionLevels,
          OfferSubscriptionLevels,
          OfferSubscriptionLevels
        >
    with $Provider<OfferSubscriptionLevels> {
  /// The pricing step's write of the offered levels.
  OfferSubscriptionLevelsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offerSubscriptionLevelsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offerSubscriptionLevelsHash();

  @$internal
  @override
  $ProviderElement<OfferSubscriptionLevels> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OfferSubscriptionLevels create(Ref ref) {
    return offerSubscriptionLevels(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OfferSubscriptionLevels value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OfferSubscriptionLevels>(value),
    );
  }
}

String _$offerSubscriptionLevelsHash() =>
    r'28f26c43c8a62d23945b17e454ecf6ca7f2ee425';

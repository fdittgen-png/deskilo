// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guest_pass_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(guestPassRepository)
final guestPassRepositoryProvider = GuestPassRepositoryProvider._();

final class GuestPassRepositoryProvider
    extends
        $FunctionalProvider<
          GuestPassRepository,
          GuestPassRepository,
          GuestPassRepository
        >
    with $Provider<GuestPassRepository> {
  GuestPassRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'guestPassRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$guestPassRepositoryHash();

  @$internal
  @override
  $ProviderElement<GuestPassRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GuestPassRepository create(Ref ref) {
    return guestPassRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GuestPassRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GuestPassRepository>(value),
    );
  }
}

String _$guestPassRepositoryHash() =>
    r'7de88a3900fb770048ac500854e76cb44a0c8574';

/// The passes of [workspaceId], by name.

@ProviderFor(guestPassOffers)
final guestPassOffersProvider = GuestPassOffersFamily._();

/// The passes of [workspaceId], by name.

final class GuestPassOffersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<GuestPassOffer>>,
          List<GuestPassOffer>,
          FutureOr<List<GuestPassOffer>>
        >
    with
        $FutureModifier<List<GuestPassOffer>>,
        $FutureProvider<List<GuestPassOffer>> {
  /// The passes of [workspaceId], by name.
  GuestPassOffersProvider._({
    required GuestPassOffersFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'guestPassOffersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$guestPassOffersHash();

  @override
  String toString() {
    return r'guestPassOffersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<GuestPassOffer>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<GuestPassOffer>> create(Ref ref) {
    final argument = this.argument as String;
    return guestPassOffers(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GuestPassOffersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$guestPassOffersHash() => r'5e34eeca389a41ebba115749dd035878605e0961';

/// The passes of [workspaceId], by name.

final class GuestPassOffersFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<GuestPassOffer>>, String> {
  GuestPassOffersFamily._()
    : super(
        retry: null,
        name: r'guestPassOffersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The passes of [workspaceId], by name.

  GuestPassOffersProvider call(String workspaceId) =>
      GuestPassOffersProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'guestPassOffersProvider';
}

/// Every seat of the active space, level by level (#3308): the places a
/// pass can book. The server checks the place is free and the window open.

@ProviderFor(guestPassPlaces)
final guestPassPlacesProvider = GuestPassPlacesProvider._();

/// Every seat of the active space, level by level (#3308): the places a
/// pass can book. The server checks the place is free and the window open.

final class GuestPassPlacesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<GuestPassPlace>>,
          List<GuestPassPlace>,
          FutureOr<List<GuestPassPlace>>
        >
    with
        $FutureModifier<List<GuestPassPlace>>,
        $FutureProvider<List<GuestPassPlace>> {
  /// Every seat of the active space, level by level (#3308): the places a
  /// pass can book. The server checks the place is free and the window open.
  GuestPassPlacesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'guestPassPlacesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$guestPassPlacesHash();

  @$internal
  @override
  $FutureProviderElement<List<GuestPassPlace>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<GuestPassPlace>> create(Ref ref) {
    return guestPassPlaces(ref);
  }
}

String _$guestPassPlacesHash() => r'7f82190870ed947e830720060238df2ac4801e90';

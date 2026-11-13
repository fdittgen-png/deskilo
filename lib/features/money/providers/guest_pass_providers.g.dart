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

/// #3614 — the passes sold in [workspaceId], the latest first.

@ProviderFor(guestPassesSold)
final guestPassesSoldProvider = GuestPassesSoldFamily._();

/// #3614 — the passes sold in [workspaceId], the latest first.

final class GuestPassesSoldProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<GuestPassRecord>>,
          List<GuestPassRecord>,
          FutureOr<List<GuestPassRecord>>
        >
    with
        $FutureModifier<List<GuestPassRecord>>,
        $FutureProvider<List<GuestPassRecord>> {
  /// #3614 — the passes sold in [workspaceId], the latest first.
  GuestPassesSoldProvider._({
    required GuestPassesSoldFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'guestPassesSoldProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$guestPassesSoldHash();

  @override
  String toString() {
    return r'guestPassesSoldProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<GuestPassRecord>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<GuestPassRecord>> create(Ref ref) {
    final argument = this.argument as String;
    return guestPassesSold(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GuestPassesSoldProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$guestPassesSoldHash() => r'df5a5ac130b1eb892d49456ebced1493e899b61b';

/// #3614 — the passes sold in [workspaceId], the latest first.

final class GuestPassesSoldFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<GuestPassRecord>>, String> {
  GuestPassesSoldFamily._()
    : super(
        retry: null,
        name: r'guestPassesSoldProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// #3614 — the passes sold in [workspaceId], the latest first.

  GuestPassesSoldProvider call(String workspaceId) =>
      GuestPassesSoldProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'guestPassesSoldProvider';
}

/// The places a pass can book in [workspaceId].

@ProviderFor(guestPassPlaces)
final guestPassPlacesProvider = GuestPassPlacesFamily._();

/// The places a pass can book in [workspaceId].

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
  /// The places a pass can book in [workspaceId].
  GuestPassPlacesProvider._({
    required GuestPassPlacesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'guestPassPlacesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$guestPassPlacesHash();

  @override
  String toString() {
    return r'guestPassPlacesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<GuestPassPlace>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<GuestPassPlace>> create(Ref ref) {
    final argument = this.argument as String;
    return guestPassPlaces(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GuestPassPlacesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$guestPassPlacesHash() => r'0c485a76655bf983e1e8f727cf33e49c20150c8b';

/// The places a pass can book in [workspaceId].

final class GuestPassPlacesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<GuestPassPlace>>, String> {
  GuestPassPlacesFamily._()
    : super(
        retry: null,
        name: r'guestPassPlacesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The places a pass can book in [workspaceId].

  GuestPassPlacesProvider call(String workspaceId) =>
      GuestPassPlacesProvider._(argument: workspaceId, from: this);

  @override
  String toString() => r'guestPassPlacesProvider';
}

/// What the guest passes screen does.

@ProviderFor(guestPassCommands)
final guestPassCommandsProvider = GuestPassCommandsProvider._();

/// What the guest passes screen does.

final class GuestPassCommandsProvider
    extends
        $FunctionalProvider<
          GuestPassCommands,
          GuestPassCommands,
          GuestPassCommands
        >
    with $Provider<GuestPassCommands> {
  /// What the guest passes screen does.
  GuestPassCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'guestPassCommandsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$guestPassCommandsHash();

  @$internal
  @override
  $ProviderElement<GuestPassCommands> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GuestPassCommands create(Ref ref) {
    return guestPassCommands(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GuestPassCommands value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GuestPassCommands>(value),
    );
  }
}

String _$guestPassCommandsHash() => r'd00214fc786f9a9c087d1e2f9248588c8b13d106';

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visits_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #1835 — the guest's own visits, over this server's definer functions.

@ProviderFor(guestParticipationRepository)
final guestParticipationRepositoryProvider =
    GuestParticipationRepositoryProvider._();

/// #1835 — the guest's own visits, over this server's definer functions.

final class GuestParticipationRepositoryProvider
    extends
        $FunctionalProvider<
          GuestParticipationRepository,
          GuestParticipationRepository,
          GuestParticipationRepository
        >
    with $Provider<GuestParticipationRepository> {
  /// #1835 — the guest's own visits, over this server's definer functions.
  GuestParticipationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'guestParticipationRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$guestParticipationRepositoryHash();

  @$internal
  @override
  $ProviderElement<GuestParticipationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GuestParticipationRepository create(Ref ref) {
    return guestParticipationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GuestParticipationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GuestParticipationRepository>(value),
    );
  }
}

String _$guestParticipationRepositoryHash() =>
    r'4abec970bdc02806679e4a7d9c873756f36f4a22';

/// The guest's actions on their own visits.

@ProviderFor(guestVisitActions)
final guestVisitActionsProvider = GuestVisitActionsProvider._();

/// The guest's actions on their own visits.

final class GuestVisitActionsProvider
    extends
        $FunctionalProvider<
          GuestVisitActions,
          GuestVisitActions,
          GuestVisitActions
        >
    with $Provider<GuestVisitActions> {
  /// The guest's actions on their own visits.
  GuestVisitActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'guestVisitActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$guestVisitActionsHash();

  @$internal
  @override
  $ProviderElement<GuestVisitActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GuestVisitActions create(Ref ref) {
    return guestVisitActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GuestVisitActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GuestVisitActions>(value),
    );
  }
}

String _$guestVisitActionsHash() => r'6a8ed6ccd956815cda8184bfcefd68c29d5bed31';

/// My visits, newest first. Nobody signed in holds none.

@ProviderFor(myGuestVisits)
final myGuestVisitsProvider = MyGuestVisitsProvider._();

/// My visits, newest first. Nobody signed in holds none.

final class MyGuestVisitsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<GuestParticipation>>,
          List<GuestParticipation>,
          FutureOr<List<GuestParticipation>>
        >
    with
        $FutureModifier<List<GuestParticipation>>,
        $FutureProvider<List<GuestParticipation>> {
  /// My visits, newest first. Nobody signed in holds none.
  MyGuestVisitsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myGuestVisitsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myGuestVisitsHash();

  @$internal
  @override
  $FutureProviderElement<List<GuestParticipation>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<GuestParticipation>> create(Ref ref) {
    return myGuestVisits(ref);
  }
}

String _$myGuestVisitsHash() => r'06839e055a41d1eeb28745762b6db95b9b776a16';

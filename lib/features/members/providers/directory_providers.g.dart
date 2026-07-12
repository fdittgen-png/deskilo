// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'directory_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// user id → profile for the active workspace's members (#224): the
/// directory derives statuses from `last_seen_at` and shows the WhatsApp
/// button for shared numbers. RLS already trims the read to people
/// sharing a workspace with the caller (#223).

@ProviderFor(memberProfiles)
final memberProfilesProvider = MemberProfilesProvider._();

/// user id → profile for the active workspace's members (#224): the
/// directory derives statuses from `last_seen_at` and shows the WhatsApp
/// button for shared numbers. RLS already trims the read to people
/// sharing a workspace with the caller (#223).

final class MemberProfilesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, Profile>>,
          Map<String, Profile>,
          FutureOr<Map<String, Profile>>
        >
    with
        $FutureModifier<Map<String, Profile>>,
        $FutureProvider<Map<String, Profile>> {
  /// user id → profile for the active workspace's members (#224): the
  /// directory derives statuses from `last_seen_at` and shows the WhatsApp
  /// button for shared numbers. RLS already trims the read to people
  /// sharing a workspace with the caller (#223).
  MemberProfilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memberProfilesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memberProfilesHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, Profile>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, Profile>> create(Ref ref) {
    return memberProfiles(ref);
  }
}

String _$memberProfilesHash() => r'03616ed6e5888fd99cd08ac564bee03885cce371';

/// All reservations feeding the directory's reservation chips (#237):
/// the month windows covering now through
/// `now + [DirectoryReservationRules.upcomingWindow]`, merged and
/// deduplicated by id (a booking spanning a month boundary appears in
/// both windows). Reuses [reservationsForMonthProvider] so the directory
/// shares the calendar's cache; the resolver
/// (`resolveReservationInfo`) trims this to what a chip actually shows.

@ProviderFor(directoryReservations)
final directoryReservationsProvider = DirectoryReservationsProvider._();

/// All reservations feeding the directory's reservation chips (#237):
/// the month windows covering now through
/// `now + [DirectoryReservationRules.upcomingWindow]`, merged and
/// deduplicated by id (a booking spanning a month boundary appears in
/// both windows). Reuses [reservationsForMonthProvider] so the directory
/// shares the calendar's cache; the resolver
/// (`resolveReservationInfo`) trims this to what a chip actually shows.

final class DirectoryReservationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Reservation>>,
          List<Reservation>,
          FutureOr<List<Reservation>>
        >
    with
        $FutureModifier<List<Reservation>>,
        $FutureProvider<List<Reservation>> {
  /// All reservations feeding the directory's reservation chips (#237):
  /// the month windows covering now through
  /// `now + [DirectoryReservationRules.upcomingWindow]`, merged and
  /// deduplicated by id (a booking spanning a month boundary appears in
  /// both windows). Reuses [reservationsForMonthProvider] so the directory
  /// shares the calendar's cache; the resolver
  /// (`resolveReservationInfo`) trims this to what a chip actually shows.
  DirectoryReservationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'directoryReservationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$directoryReservationsHash();

  @$internal
  @override
  $FutureProviderElement<List<Reservation>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Reservation>> create(Ref ref) {
    return directoryReservations(ref);
  }
}

String _$directoryReservationsHash() =>
    r'a5bd08b78bda4b42398638bb0fe8e651a4201779';

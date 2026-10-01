// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'directory_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// user id → profile for the active workspace's members (#224): the
/// directory derives statuses from `last_seen_at` and shows the WhatsApp
/// button for shared numbers. #1833: each profile is the projection the
/// caller may read in this space — the community fields for a space
/// mate, the printed identity only with `viewPersonalData` or
/// `issueInvoices` (invoices, letters, the Excel export).

@ProviderFor(memberProfiles)
final memberProfilesProvider = MemberProfilesProvider._();

/// user id → profile for the active workspace's members (#224): the
/// directory derives statuses from `last_seen_at` and shows the WhatsApp
/// button for shared numbers. #1833: each profile is the projection the
/// caller may read in this space — the community fields for a space
/// mate, the printed identity only with `viewPersonalData` or
/// `issueInvoices` (invoices, letters, the Excel export).

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
  /// button for shared numbers. #1833: each profile is the projection the
  /// caller may read in this space — the community fields for a space
  /// mate, the printed identity only with `viewPersonalData` or
  /// `issueInvoices` (invoices, letters, the Excel export).
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

String _$memberProfilesHash() => r'b16eace7d4bd05f79c63ba42625a06ebdd5c7de4';

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
    r'3821e13903e1ec0b310aad913f91fff394cfc66c';

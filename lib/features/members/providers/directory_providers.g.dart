// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'directory_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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
    r'0246b32346af3a87c584feef378c0cafd7e6df4e';

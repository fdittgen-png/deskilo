// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reservation_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(reservationRepository)
final reservationRepositoryProvider = ReservationRepositoryProvider._();

final class ReservationRepositoryProvider
    extends
        $FunctionalProvider<
          ReservationRepository,
          ReservationRepository,
          ReservationRepository
        >
    with $Provider<ReservationRepository> {
  ReservationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reservationRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reservationRepositoryHash();

  @$internal
  @override
  $ProviderElement<ReservationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReservationRepository create(Ref ref) {
    return reservationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReservationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReservationRepository>(value),
    );
  }
}

String _$reservationRepositoryHash() =>
    r'55f521658d95cec06053ca711f6d9e0e5a1c8712';

/// Reservations of the active workspace intersecting the given LOCAL day
/// (keyed 'yyyy-MM-dd'). Local, not UTC: the user thinks in wall-clock
/// days, and a UTC window shifts the visible day east/west of UTC (#119).

@ProviderFor(reservationsForDay)
final reservationsForDayProvider = ReservationsForDayFamily._();

/// Reservations of the active workspace intersecting the given LOCAL day
/// (keyed 'yyyy-MM-dd'). Local, not UTC: the user thinks in wall-clock
/// days, and a UTC window shifts the visible day east/west of UTC (#119).

final class ReservationsForDayProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Reservation>>,
          List<Reservation>,
          FutureOr<List<Reservation>>
        >
    with
        $FutureModifier<List<Reservation>>,
        $FutureProvider<List<Reservation>> {
  /// Reservations of the active workspace intersecting the given LOCAL day
  /// (keyed 'yyyy-MM-dd'). Local, not UTC: the user thinks in wall-clock
  /// days, and a UTC window shifts the visible day east/west of UTC (#119).
  ReservationsForDayProvider._({
    required ReservationsForDayFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'reservationsForDayProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reservationsForDayHash();

  @override
  String toString() {
    return r'reservationsForDayProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Reservation>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Reservation>> create(Ref ref) {
    final argument = this.argument as String;
    return reservationsForDay(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReservationsForDayProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reservationsForDayHash() =>
    r'dd2474ececfead1ef7a55f022045539f7e84b5c9';

/// Reservations of the active workspace intersecting the given LOCAL day
/// (keyed 'yyyy-MM-dd'). Local, not UTC: the user thinks in wall-clock
/// days, and a UTC window shifts the visible day east/west of UTC (#119).

final class ReservationsForDayFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Reservation>>, String> {
  ReservationsForDayFamily._()
    : super(
        retry: null,
        name: r'reservationsForDayProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Reservations of the active workspace intersecting the given LOCAL day
  /// (keyed 'yyyy-MM-dd'). Local, not UTC: the user thinks in wall-clock
  /// days, and a UTC window shifts the visible day east/west of UTC (#119).

  ReservationsForDayProvider call(String dayKey) =>
      ReservationsForDayProvider._(argument: dayKey, from: this);

  @override
  String toString() => r'reservationsForDayProvider';
}

/// My reserved (not yet checked-in) bookings starting within 7 days —
/// feeds the local check-in reminders (spec §4.3).

@ProviderFor(myUpcomingReservations)
final myUpcomingReservationsProvider = MyUpcomingReservationsProvider._();

/// My reserved (not yet checked-in) bookings starting within 7 days —
/// feeds the local check-in reminders (spec §4.3).

final class MyUpcomingReservationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Reservation>>,
          List<Reservation>,
          FutureOr<List<Reservation>>
        >
    with
        $FutureModifier<List<Reservation>>,
        $FutureProvider<List<Reservation>> {
  /// My reserved (not yet checked-in) bookings starting within 7 days —
  /// feeds the local check-in reminders (spec §4.3).
  MyUpcomingReservationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myUpcomingReservationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myUpcomingReservationsHash();

  @$internal
  @override
  $FutureProviderElement<List<Reservation>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Reservation>> create(Ref ref) {
    return myUpcomingReservations(ref);
  }
}

String _$myUpcomingReservationsHash() =>
    r'510da65c16d475b12fe5f5f80a6845ebd939512b';

/// member id → display name for the active workspace.

@ProviderFor(memberNames)
final memberNamesProvider = MemberNamesProvider._();

/// member id → display name for the active workspace.

final class MemberNamesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, String>>,
          Map<String, String>,
          FutureOr<Map<String, String>>
        >
    with
        $FutureModifier<Map<String, String>>,
        $FutureProvider<Map<String, String>> {
  /// member id → display name for the active workspace.
  MemberNamesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memberNamesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memberNamesHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, String>> create(Ref ref) {
    return memberNames(ref);
  }
}

String _$memberNamesHash() => r'004c24caf27181af8978ae9eade5c76d7b3a50e3';

/// Reservations of the active workspace intersecting the given LOCAL
/// month (keyed 'yyyy-MM'). See [reservationsForDay] for why local (#119):
/// a UTC key turned the July calendar into a June query east of UTC.

@ProviderFor(reservationsForMonth)
final reservationsForMonthProvider = ReservationsForMonthFamily._();

/// Reservations of the active workspace intersecting the given LOCAL
/// month (keyed 'yyyy-MM'). See [reservationsForDay] for why local (#119):
/// a UTC key turned the July calendar into a June query east of UTC.

final class ReservationsForMonthProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Reservation>>,
          List<Reservation>,
          FutureOr<List<Reservation>>
        >
    with
        $FutureModifier<List<Reservation>>,
        $FutureProvider<List<Reservation>> {
  /// Reservations of the active workspace intersecting the given LOCAL
  /// month (keyed 'yyyy-MM'). See [reservationsForDay] for why local (#119):
  /// a UTC key turned the July calendar into a June query east of UTC.
  ReservationsForMonthProvider._({
    required ReservationsForMonthFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'reservationsForMonthProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reservationsForMonthHash();

  @override
  String toString() {
    return r'reservationsForMonthProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Reservation>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Reservation>> create(Ref ref) {
    final argument = this.argument as String;
    return reservationsForMonth(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReservationsForMonthProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reservationsForMonthHash() =>
    r'b00f5c11b7eb515f11dee1943ca482036556746a';

/// Reservations of the active workspace intersecting the given LOCAL
/// month (keyed 'yyyy-MM'). See [reservationsForDay] for why local (#119):
/// a UTC key turned the July calendar into a June query east of UTC.

final class ReservationsForMonthFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Reservation>>, String> {
  ReservationsForMonthFamily._()
    : super(
        retry: null,
        name: r'reservationsForMonthProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Reservations of the active workspace intersecting the given LOCAL
  /// month (keyed 'yyyy-MM'). See [reservationsForDay] for why local (#119):
  /// a UTC key turned the July calendar into a June query east of UTC.

  ReservationsForMonthProvider call(String monthKey) =>
      ReservationsForMonthProvider._(argument: monthKey, from: this);

  @override
  String toString() => r'reservationsForMonthProvider';
}

/// #1643 — the calendar-file command, wired to the seams it needs so the
/// button that asks for a file resolves no repository of its own.
///
/// The installation is the backend HOST: a reservation id is unique to a
/// backend, so the two together identify the booking wherever the file
/// is imported — and only a digest of them ever leaves the device.
///
/// Kept alive: the command holds closures that read providers through
/// this `ref` when the member taps Save, long after the preview future
/// completed — an auto-disposed provider would have thrown by then.

@ProviderFor(calendarFiles)
final calendarFilesProvider = CalendarFilesProvider._();

/// #1643 — the calendar-file command, wired to the seams it needs so the
/// button that asks for a file resolves no repository of its own.
///
/// The installation is the backend HOST: a reservation id is unique to a
/// backend, so the two together identify the booking wherever the file
/// is imported — and only a digest of them ever leaves the device.
///
/// Kept alive: the command holds closures that read providers through
/// this `ref` when the member taps Save, long after the preview future
/// completed — an auto-disposed provider would have thrown by then.

final class CalendarFilesProvider
    extends
        $FunctionalProvider<
          AsyncValue<CalendarFiles>,
          CalendarFiles,
          FutureOr<CalendarFiles>
        >
    with $FutureModifier<CalendarFiles>, $FutureProvider<CalendarFiles> {
  /// #1643 — the calendar-file command, wired to the seams it needs so the
  /// button that asks for a file resolves no repository of its own.
  ///
  /// The installation is the backend HOST: a reservation id is unique to a
  /// backend, so the two together identify the booking wherever the file
  /// is imported — and only a digest of them ever leaves the device.
  ///
  /// Kept alive: the command holds closures that read providers through
  /// this `ref` when the member taps Save, long after the preview future
  /// completed — an auto-disposed provider would have thrown by then.
  CalendarFilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'calendarFilesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$calendarFilesHash();

  @$internal
  @override
  $FutureProviderElement<CalendarFiles> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CalendarFiles> create(Ref ref) {
    return calendarFiles(ref);
  }
}

String _$calendarFilesHash() => r'083bd828b2c0ed92cef2fb39213fa7c6e04218be';

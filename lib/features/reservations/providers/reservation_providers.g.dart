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
    r'3e7e1c9b286d791bf252ab662e2454c870f11c65';

/// Reservations of the active workspace intersecting the given UTC day
/// (keyed by 'yyyy-MM-dd' to keep family keys canonical).

@ProviderFor(reservationsForDay)
final reservationsForDayProvider = ReservationsForDayFamily._();

/// Reservations of the active workspace intersecting the given UTC day
/// (keyed by 'yyyy-MM-dd' to keep family keys canonical).

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
  /// Reservations of the active workspace intersecting the given UTC day
  /// (keyed by 'yyyy-MM-dd' to keep family keys canonical).
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
    r'a7f247339c0645ca251e642b0110bee6e64ac12a';

/// Reservations of the active workspace intersecting the given UTC day
/// (keyed by 'yyyy-MM-dd' to keep family keys canonical).

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

  /// Reservations of the active workspace intersecting the given UTC day
  /// (keyed by 'yyyy-MM-dd' to keep family keys canonical).

  ReservationsForDayProvider call(String dayKey) =>
      ReservationsForDayProvider._(argument: dayKey, from: this);

  @override
  String toString() => r'reservationsForDayProvider';
}

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

String _$memberNamesHash() => r'8ff1556b61a23f9f8aa631319aea472451bb2143';

/// Reservations of the active workspace intersecting the given month
/// (keyed 'yyyy-MM').

@ProviderFor(reservationsForMonth)
final reservationsForMonthProvider = ReservationsForMonthFamily._();

/// Reservations of the active workspace intersecting the given month
/// (keyed 'yyyy-MM').

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
  /// Reservations of the active workspace intersecting the given month
  /// (keyed 'yyyy-MM').
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
    r'03e02f89e7f21311a58ccceeb58991caa64a04cc';

/// Reservations of the active workspace intersecting the given month
/// (keyed 'yyyy-MM').

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

  /// Reservations of the active workspace intersecting the given month
  /// (keyed 'yyyy-MM').

  ReservationsForMonthProvider call(String monthKey) =>
      ReservationsForMonthProvider._(argument: monthKey, from: this);

  @override
  String toString() => r'reservationsForMonthProvider';
}

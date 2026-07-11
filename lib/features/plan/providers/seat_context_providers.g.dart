// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seat_context_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where one seat lives (#182): level · office · desk · seat names for the
/// calendar's reservation detail sheet. Null for an unknown seat.

@ProviderFor(seatContext)
final seatContextProvider = SeatContextFamily._();

/// Where one seat lives (#182): level · office · desk · seat names for the
/// calendar's reservation detail sheet. Null for an unknown seat.

final class SeatContextProvider
    extends
        $FunctionalProvider<
          AsyncValue<SeatContext?>,
          SeatContext?,
          FutureOr<SeatContext?>
        >
    with $FutureModifier<SeatContext?>, $FutureProvider<SeatContext?> {
  /// Where one seat lives (#182): level · office · desk · seat names for the
  /// calendar's reservation detail sheet. Null for an unknown seat.
  SeatContextProvider._({
    required SeatContextFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'seatContextProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$seatContextHash();

  @override
  String toString() {
    return r'seatContextProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SeatContext?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SeatContext?> create(Ref ref) {
    final argument = this.argument as String;
    return seatContext(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SeatContextProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$seatContextHash() => r'20b6c2127594354c52ce3cd07d54a068dad69cb1';

/// Where one seat lives (#182): level · office · desk · seat names for the
/// calendar's reservation detail sheet. Null for an unknown seat.

final class SeatContextFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<SeatContext?>, String> {
  SeatContextFamily._()
    : super(
        retry: null,
        name: r'seatContextProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Where one seat lives (#182): level · office · desk · seat names for the
  /// calendar's reservation detail sheet. Null for an unknown seat.

  SeatContextProvider call(String seatId) =>
      SeatContextProvider._(argument: seatId, from: this);

  @override
  String toString() => r'seatContextProvider';
}

/// [seatContext] for a whole-office reservation: level + office names only.

@ProviderFor(officeContext)
final officeContextProvider = OfficeContextFamily._();

/// [seatContext] for a whole-office reservation: level + office names only.

final class OfficeContextProvider
    extends
        $FunctionalProvider<
          AsyncValue<SeatContext?>,
          SeatContext?,
          FutureOr<SeatContext?>
        >
    with $FutureModifier<SeatContext?>, $FutureProvider<SeatContext?> {
  /// [seatContext] for a whole-office reservation: level + office names only.
  OfficeContextProvider._({
    required OfficeContextFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'officeContextProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$officeContextHash();

  @override
  String toString() {
    return r'officeContextProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SeatContext?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SeatContext?> create(Ref ref) {
    final argument = this.argument as String;
    return officeContext(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is OfficeContextProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$officeContextHash() => r'05883b623215f3968838a108d15b045cf931ddcb';

/// [seatContext] for a whole-office reservation: level + office names only.

final class OfficeContextFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<SeatContext?>, String> {
  OfficeContextFamily._()
    : super(
        retry: null,
        name: r'officeContextProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// [seatContext] for a whole-office reservation: level + office names only.

  OfficeContextProvider call(String officeId) =>
      OfficeContextProvider._(argument: officeId, from: this);

  @override
  String toString() => r'officeContextProvider';
}

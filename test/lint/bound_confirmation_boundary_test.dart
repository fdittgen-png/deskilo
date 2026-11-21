// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4283 (a gap of #4174) — a confirmation cannot skip the binding.
//
// A reservation confirmation acts on the business and account it was opened
// in (`BoundReservation`, #4157): every write goes through the handle taken
// when the confirmation opened. Two things keep a new confirmation honest:
//
// 1. the files of the named confirmation handlers never reach the reservation
//    repository on their own — the one place that may read it is the capture
//    of the handle itself; and
// 2. every public confirmation of `ReservationDetailActions` has a named case
//    in `bound_confirmation_switch_test.dart`, so a handler added or renamed
//    there cannot be left unpumped.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _handlerFiles = [
  'lib/features/reservations/presentation/reserve_seat_actions.dart',
  'lib/features/reservations/presentation/widgets/reservation_detail_actions.dart',
  'lib/features/reservations/presentation/widgets/reservation_detail_sheet.dart',
  'lib/app/desk_calendar/desk_booking_pane.dart',
];

/// The only line of these files that may name the repository's provider: the
/// capture of the handle (it hands the repository to the handle, it writes
/// nothing).
const _capture = 'reservations: ref.read(reservationRepositoryProvider),';

/// The public confirmations of `ReservationDetailActions`, each with the case
/// of the switch test that pumps it.
const _confirmations = {
  'requestDeletion',
  'cancel',
  'editTimes',
  'extendEnd',
  'endEarly',
};

void main() {
  test('the confirmation handlers write through the bound handle, never '
      'through the reservation repository', () {
    final offenders = <String>[];
    for (final path in _handlerFiles) {
      final lines = File(path).readAsLinesSync();
      for (final (i, line) in lines.indexed) {
        if (!line.contains('reservationRepositoryProvider')) continue;
        if (line.trim() == _capture) continue;
        offenders.add('$path:${i + 1}: ${line.trim()}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'a confirmation handler writes through BoundReservation '
          '(`withReservations`, `perform`, `book`), which refuses when the '
          'business or account changed while it was open (#4157); reading '
          'the repository here bypasses it',
    );
  });

  test('the repository the handle wraps has writes this lint knows to '
      'be bound', () {
    // The writes of the interface (everything that is not a read): a new one
    // is a new way for a confirmation to skip the binding, so it is named here
    // and in `BoundReservation` before it is used.
    final source = File(
      'lib/features/reservations/domain/reservation_repository.dart',
    ).readAsStringSync();
    final method = RegExp(
      r'^\s+(?:Future|Stream)<.*?>\s+(\w+)\(',
      multiLine: true,
    );
    final writes = {
      for (final m in method.allMatches(source))
        if (!m.group(1)!.startsWith('fetch') && m.group(1) != 'requestOutcome')
          m.group(1)!,
    };
    expect(
      writes,
      {
        'create',
        'createFor',
        'checkIn',
        'checkOut',
        'cancel',
        'kioskIdentify',
        'kioskAct',
        'updateTimes',
        'createSeries',
        'convertToSeries',
        'cancelSeries',
      },
      reason:
          'a new write on the repository must be reached through '
          'BoundReservation, and be pumped across a change of business',
    );
  });

  test('every public confirmation of ReservationDetailActions has a named '
      'case in the switch test', () {
    final source = File(
      'lib/features/reservations/presentation/widgets/'
      'reservation_detail_actions.dart',
    ).readAsStringSync();
    final publicFutures = {
      for (final m in RegExp(
        r'^  Future<[^\n]*?>\s+([a-z]\w*)\(',
        multiLine: true,
      ).allMatches(source))
        m.group(1)!,
    };
    expect(
      publicFutures,
      _confirmations,
      reason:
          'a public confirmation was added or renamed: pump it in '
          'bound_confirmation_switch_test.dart (named '
          '`ReservationDetailActions.<name>`) and list it here',
    );

    final cases = File(
      'test/features/reservations/bound_confirmation_switch_test.dart',
    ).readAsStringSync();
    final unpumped = [
      for (final name in _confirmations)
        if (!cases.contains('ReservationDetailActions.$name')) name,
    ];
    expect(
      unpumped,
      isEmpty,
      reason: 'no case of the switch test names these confirmations',
    );
  });
}

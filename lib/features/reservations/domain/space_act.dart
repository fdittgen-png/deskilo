// SPDX-License-Identifier: 0BSD
//
// #1234 — what a space act IS, separated from the form that collects it.
//
// These two types were declared at the top of
// `presentation/widgets/space_act_form.dart`, which imports
// `package:flutter/material.dart`. That was harmless while only widgets
// named them; it stopped being harmless when `application/act_on_space.dart`
// needed them, because an application command that imports a Flutter
// widget file drags Material into the layer ADR 0024 defines as the one
// that decides which write to make and nothing else.
//
// Nothing enforced that: `layering_test` checks `/domain/` for Flutter
// imports and says nothing about `/application/`. The lint now covers
// both — a convention three files happened to honour was not a rule.
//
// They belong here on their own merit. "Which of the three operations
// did the member choose, over which window" is a fact about a booking,
// not about a bottom sheet: the kiosk one-sheet (#529) and the app's
// scan flow (#622) both produce it, and now the command consumes it.
import '../../workspace/domain/booking_granularity.dart';
import 'reservation.dart';

/// What a space act does — the three operations the kiosk one-sheet
/// offers (#529) and, since #622, the app's scan flow too.
enum SpaceAction { checkIn, reserve, checkOut }

/// The state of the act form at completion time: the action, the window
/// it books (ignored for check-out) and whether a begun reservation
/// starts checked in.
typedef SpaceActChoice = ({
  SpaceAction action,
  DateTime start,
  DateTime end,
  bool checkInNow,
});

/// Everything [actOnSpace] needs, and nothing about how it was asked.
///
/// The provider reads stay in the sheet, which passes values down — the
/// same shape as `book_seat.dart`. `dayReservations` is today's slice the
/// sheet already watches: passing it keeps the command pure rather than
/// making it fetch, and lets a test hand it three rows instead of
/// standing up a provider scope.
typedef SpaceActRequest = ({
  String workspaceId,
  String seatId,
  SpaceActChoice choice,
  List<Reservation> dayReservations,
  String? myMemberId,
  DateTime now,
  BookingGranularity granularity,
});

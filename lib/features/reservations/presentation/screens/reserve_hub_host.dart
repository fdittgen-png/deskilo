// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What the Reserve hub's views ask of the screen that owns them (#2494). The
// screen's State keeps the browsed day, window, view and focus; the plan, day,
// week and month views and the header are widgets that read them through this
// seam and call back through it.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../plan/domain/seat.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../domain/reservation.dart';
import '../widgets/reserve_canvas.dart';
import '../widgets/reserve_view_menu.dart';



abstract interface class ReserveHubHost {
  /// Local midnight of the browsed day.
  DateTime get selectedDay;

  /// Local midnight of the day the hub opened on.
  DateTime get today;

  ReserveView get view;

  /// LIVE = today with no hand-picked window: a free-seat tap is a walk-up.
  bool get isLive;

  BookingGranularity get granularity;

  /// The window the hub currently browses/books on [selectedDay].
  HalfDayWindow get bookingWindow;

  ReserveFocus get focus;

  /// The OPEN day around [at] (#903, #908): what the divided seat fill and
  /// the seat-day timeline measure themselves against.
  ({DateTime start, DateTime end}) dayWindow(DateTime at);

  DateTime defaultEndFor(DateTime from);

  /// Central day switch: re-maps the window onto the new day.
  void selectDay(DateTime day);

  void showView(ReserveView view);

  /// Drops the jump highlight.
  void clearFocus();

  Future<void> openReservation(Reservation reservation);

  Future<void> onSeatTap(
    FloorPlan plan,
    Seat seat,
    List<Reservation> reservations,
    HalfDayWindow window,
  );

  Future<void> bookingSheet(
    Seat seat,
    List<Reservation> reservations,
    HalfDayWindow window,
  );

  BuildContext get context;
}

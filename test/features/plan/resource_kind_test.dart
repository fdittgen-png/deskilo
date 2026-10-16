// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2631 — a room and a parking slot are rows of the seats table told apart
// by a kind that is persisted by name: the names are the wire contract the
// migration's check constraint accepts, and a seat stays the default.
import 'dart:io';

import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the kind names are the ones the table accepts', () {
    final sql = File('supabase/migrations/0442_meeting_rooms.sql')
        .readAsStringSync();
    expect(sql, contains("resource_kind in ('seat', 'room', 'parking')"));
    expect(ResourceKind.values.map((k) => k.name), ['seat', 'room', 'parking']);
  });

  test('a seat is the default and holds no capacity', () {
    const seat = Seat(
      id: 's',
      workspaceId: 'w',
      deskId: 'd',
      name: '',
      x: 0,
      y: 0,
      orientation: SeatOrientation.n,
      chair: '',
      amenities: [],
    );
    expect(seat.resourceKind, ResourceKind.seat);
    expect(seat.capacity, isNull);
    expect(seat.slotMinutes, isNull);
  });
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2631 — the parking kinds and the area kinds are persisted by name: the
// names are the wire contract the migration's check constraints accept.
import 'dart:io';

import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the names are the ones the table accepts', () {
    final sql = File('supabase/migrations/0444_parking.sql').readAsStringSync();
    expect(sql, contains("parking_kind in ('standard', 'ev', 'accessible')"));
    expect(sql, contains("area_kind in ('workspace', 'parking')"));
    expect(ParkingKind.values.map((k) => k.name), [
      'standard',
      'ev',
      'accessible',
    ]);
    expect(AreaKind.values.map((k) => k.name), ['workspace', 'parking']);
  });
}

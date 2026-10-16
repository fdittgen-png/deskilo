// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2631 — a charging station's connectors are the wire contract the table
// accepts, and the migration keeps the three rules the acceptance names:
// an EV slot is booked with its charger, a non-EV slot has none, and the
// usage fee rides the existing accessory supplement.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File('supabase/migrations/0446_charging_stations.sql')
      .readAsStringSync();

  test('the connectors the table accepts', () {
    expect(
      sql,
      contains("connector in ('type2', 'ccs', 'chademo', 'tesla', 'schuko')"),
    );
  });

  test('the booking, the EV-only and the fee rules are in the migration', () {
    expect(sql, contains('the charging station of this slot is not available'));
    expect(sql, contains('a charging station belongs to an EV parking slot'));
    expect(sql, contains('insert into public.seat_accessories'));
  });
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1334 — a database test may not depend on the hour the pipeline runs.
//
// Twice now a pgTAP file has turned red for the clock rather than for a
// defect: `24_booking_idempotency` booked a Saturday when the pipeline
// ran on a Friday (#1476), and `23_domain_invariants` checked in at
// 02:05 Paris, outside the working day the product's defaults describe,
// on every pull request built at night. Both failures named an invariant
// that was perfectly fine.
//
// The rule: a file that drives one of the RPCs which READ `booking_rules`
// — the check-in window, the closed-day gate, the opening hours — must
// state the hours and days it needs. A fixture that borrows whatever the
// defaults happen to be is a fixture that fails on a Sunday.
//
// Inserting a reservation row directly is not covered: those inserts
// bypass the gates, which is why `11_tenancy_matrix` and
// `43_event_validation_rules` are silent here and correct.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The RPCs whose refusals are the clock itself — "check-in window
/// closed", "check-in window not open yet", "outside the opening hours".
/// Deliberately only these: a deletion request or a series conversion
/// reads the policies, not the hour, and listing them would make the
/// rule fire where there is nothing to fix.
const gatedCalls = [
  'check_in_reservation',
  'kiosk_act',
  'complete_check_out',
];

/// Files that call one of those and deliberately do NOT open their week,
/// with the reason. A file testing the refusal itself belongs here.
const Map<String, String> statesItsOwnClock = {};

/// True when [sql] places its fixtures relative to the machine's clock.
bool usesTheClock(String sql) =>
    RegExp(r"now\(\)\s*[-+]|current_date|current_timestamp").hasMatch(sql);

/// True when [sql] pins the days and hours its space is open.
bool opensItsWeek(String sql) =>
    sql.contains('open_weekdays') &&
    RegExp(r'work_start_minutes').hasMatch(sql) &&
    RegExp(r'work_end_minutes').hasMatch(sql);

/// The files that drive a gated RPC against a clock-relative fixture
/// without saying when their space is open.
List<String> clockDependentFiles(Iterable<File> files) {
  final out = <String>[];
  for (final file in files) {
    final sql = file.readAsStringSync();
    final name = file.uri.pathSegments.last;
    if (statesItsOwnClock.containsKey(name)) continue;
    final calls = gatedCalls.where(sql.contains).toList();
    if (calls.isEmpty) continue;
    if (!usesTheClock(sql)) continue;
    if (opensItsWeek(sql)) continue;
    out.add('$name: calls ${calls.join(', ')} against a now()-relative '
        'fixture without opening its week');
  }
  return out;
}

void main() {
  test('no database test depends on the hour the pipeline runs', () {
    final files = Directory('supabase/tests/database')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, isNotEmpty, reason: 'the suite moved; fix the path');

    expect(
      clockDependentFiles(files),
      isEmpty,
      reason: 'set the space open every weekday, 00:00–24:00, in the '
          "file's own seed — as 23_domain_invariants and "
          '24_booking_idempotency do — or add the file to '
          'statesItsOwnClock with the reason it must not.',
    );
  });

  test('the rule fires on the shape that has failed twice, and leaves a '
      'direct insert alone', () {
    final dir = Directory.systemTemp.createTempSync('clock-lint');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/90_checks_in.sql').writeAsStringSync('''
insert into public.reservations (workspace_id, member_id, starts_at, ends_at)
values (ws, m, now() - interval '10 minutes', now() + interval '4 hours');
select lives_ok(\$\$ select public.check_in_reservation(r) \$\$, 'checks in');
''');
    File('${dir.path}/91_direct_insert.sql').writeAsStringSync('''
insert into public.reservations (workspace_id, member_id, starts_at, ends_at)
values (ws, m, now() + interval '1 day', now() + interval '1 day 4 hours');
select is(1, 1, 'a row is a row');
''');
    File('${dir.path}/92_opens_its_week.sql').writeAsStringSync('''
update public.workspaces set booking_rules = booking_rules
  || '{"open_weekdays": [1,2,3,4,5,6,7], "work_start_minutes": 0,
        "work_end_minutes": 1440}'::jsonb where id = ws;
insert into public.reservations (workspace_id, member_id, starts_at, ends_at)
values (ws, m, now() - interval '10 minutes', now() + interval '4 hours');
select lives_ok(\$\$ select public.check_in_reservation(r) \$\$, 'checks in');
''');

    final found = clockDependentFiles(
      dir.listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path)),
    );
    expect(found, hasLength(1));
    expect(found.single, startsWith('90_checks_in.sql'));
    expect(found.single, contains('check_in_reservation'));
  });
}

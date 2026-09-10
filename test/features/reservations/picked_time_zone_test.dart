// SPDX-License-Identifier: 0BSD
//
// #1082 — a picked time is a WORKSPACE wall-clock time.
//
// The booking surfaces built `DateTime(day.year, …, t.hour, t.minute)`,
// a bare device-local instant, and assigned it to fields that hold
// workspace TZDateTimes. Workspace in Paris, phone in New York: pick
// 10:00 and the tile re-renders as 16:00 and books 16:00 Paris.
//
// `reserve_screen.windowIsNow` had the mirror-image version: it fed
// `clock.now().hour` — a DEVICE-local field — into `WorkspaceTime.at`
// as if it were workspace wall-clock, so the live-window probe judged
// the wrong half of the day.
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/reservations/domain/picked_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => WorkspaceTime.install('Europe/Paris'));
  tearDown(WorkspaceTime.reset);

  final day = DateTime(2026, 8, 3);

  test('a picked wall-clock time lands on the WORKSPACE clock', () {
    final picked = pickedInstantAt(day, 10, 0);

    expect(picked, WorkspaceTime.at(2026, 8, 3, 10, 0));
    // The workspace reads it back as the hour the member chose, whatever
    // zone the device is in.
    expect(WorkspaceTime.wall(picked).hour, 10);
    // And it is NOT the bare device-local instant that used to be built.
    expect(picked, isNot(DateTime(2026, 8, 3, 10, 0)));
  });

  test('the wall clock of an instant is read on the workspace clock', () {
    // A UTC instant that is 15:00 in Paris (CEST, UTC+2) in August.
    final instant = DateTime.utc(2026, 8, 3, 13, 0);
    expect(workspaceWallMinutes(instant), 15 * 60);
  });
}

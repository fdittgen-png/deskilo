// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3484 — `AppFormat.wall` keeps `WorkspaceTime.display`'s rule: a bare
// instant goes to the clock the reader chose; a zone-carrying window (a
// workspace-anchored TZDateTime) passes through in its own wall clock.
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/core/i18n/format_prefs.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);
  setUp(() => WorkspaceTime.install('Asia/Tokyo'));
  tearDown(() => WorkspaceTime.install(null));

  const device = AppFormat(
    locale: 'en_GB',
    currencyCode: 'EUR',
    timeZoneMode: TimeZoneMode.device,
  );
  const workspace = AppFormat(locale: 'en_GB', currencyCode: 'EUR');

  test('a workspace-anchored window passes through in either mode', () {
    final morningEnd = tz.TZDateTime(tz.getLocation('Asia/Tokyo'), 2026, 11, 10, 13);
    expect(device.wall(morningEnd).hour, 13);
    expect(workspace.wall(morningEnd).hour, 13);
  });

  test('a bare instant reads in the workspace clock under workspace mode', () {
    final instant = DateTime.utc(2026, 11, 10, 4); // 13:00 in Tokyo
    expect(workspace.wall(instant).hour, 13);
    expect(device.wall(instant), instant.toLocal());
  });
}

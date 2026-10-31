// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2578 — a period's bounds on the workspace clock: October, whose last
// Sunday gives an hour back, and a leap February.
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/providers/bi_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => WorkspaceTime.install('Europe/Paris'));
  tearDown(WorkspaceTime.reset);

  test('October runs from local midnight to local midnight: 745 hours', () {
    final october = biInterval(const BiPeriod(BiGrain.month, 2026, 10));
    expect(october.from.toUtc(), DateTime.utc(2026, 9, 30, 22));
    expect(october.to.toUtc(), DateTime.utc(2026, 10, 31, 23));
    expect(october.to.difference(october.from).inHours, 31 * 24 + 1);
  });

  test('March loses its hour: 743 hours', () {
    final march = biInterval(const BiPeriod(BiGrain.month, 2026, 3));
    expect(march.to.difference(march.from).inHours, 31 * 24 - 1);
  });

  test('a leap February has its 29th day', () {
    final february = biInterval(const BiPeriod(BiGrain.month, 2028, 2));
    expect(february.from.toUtc(), DateTime.utc(2028, 1, 31, 23));
    expect(february.to.toUtc(), DateTime.utc(2028, 2, 29, 23));
    expect(february.to.difference(february.from).inDays, 29);
  });

  test('a year holds both changes and the leap day: 366 days', () {
    final year = biInterval(const BiPeriod(BiGrain.year, 2028, 1));
    expect(year.to.difference(year.from).inHours, 366 * 24);
  });
}

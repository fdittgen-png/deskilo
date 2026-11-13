// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3659 -- the Demo's Me reads invoices from four businesses, each on its
// own calendar: every invoice carries its business's zone, so "overdue" and
// the due line follow that business's day (New York's is not Pézenas's).
import 'package:deskilo/core/demo/demo_finance_projection.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/time/business_day.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every Demo invoice in Me carries its own business\'s zone', () {
    final fixture = DemoFixture.build();
    final zones = {
      for (final w in fixture.workspaces.workspaces) w.id: w.timezone,
    };
    final invoices = demoFinanceForUser(fixture.personalSpaces, fixture.auth.currentUserId).invoices;
    expect(invoices, isNotEmpty);
    for (final i in invoices) {
      expect(i.timezone, zones[i.workspaceId], reason: i.number);
      expect(
        businessTodayAt(DateTime.utc(2026, 11, 11, 23, 30), i.timezone),
        isA<KnownBusinessDay>(),
        reason: '${i.number}: a Demo business always has a calendar',
      );
    }
    expect(
      {for (final i in invoices) i.timezone}.length,
      greaterThan(1),
      reason: 'Me shows businesses in more than one zone',
    );
  });
}

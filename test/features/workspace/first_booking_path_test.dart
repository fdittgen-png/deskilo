// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3062 -- the first-booking path of a new owner, as the app's catalogue
// states it. The database half is supabase/tests/database/345: a clean space
// walked from creation to a member's booking. Here: every step of that path
// opens a registered workspace screen -- never a personal /settings page --
// the "bookable" outcome waits for exactly the four required steps the
// server counts, and the booking step waits for the resource and the
// members' right and for nothing else.
import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/features/workspace/domain/setup_steps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final path = [
    for (final s in setupSteps)
      if (s.milestone == SetupMilestone.bookable || s.id == 'first_booking') s,
  ];

  test('the first-booking path is the steps the server evidences', () {
    expect(path.map((s) => s.id), [
      'basics',
      'hours',
      'places',
      'member_rights',
      'invite',
      'first_booking',
    ]);
  });

  test('every step opens a registered workspace screen, never /settings', () {
    for (final s in path) {
      expect(
        classifyRoute(s.route.split('?').first),
        anyOf(RouteClass.workspace, RouteClass.nativeAccount),
        reason: '${s.id} -> ${s.route} must be a registered route',
      );
      expect(
        s.route,
        isNot(startsWith('/settings')),
        reason: '${s.id} must not send an owner to a personal screen',
      );
      expect(classifyRoute(s.route), RouteClass.workspace, reason: s.id);
    }
  });

  test('the bookable outcome waits for the four required steps, and the '
      'first booking for the resource and the right alone', () {
    final required = [
      for (final s in path)
        if (s.milestone == SetupMilestone.bookable && s.required) s.id,
    ];
    expect(required, ['basics', 'hours', 'places', 'member_rights']);
    final booking = path.singleWhere((s) => s.id == 'first_booking');
    expect(booking.dependsOn, ['places', 'member_rights']);
    expect(booking.evidence, 'first_booking');
    expect(booking.required, isTrue);
  });

  test('inviting people waits for the right to book, so nobody is invited '
      'into a space they cannot use', () {
    final invite = path.singleWhere((s) => s.id == 'invite');
    expect(invite.dependsOn, ['member_rights']);
    expect(invite.required, isFalse);
  });
}

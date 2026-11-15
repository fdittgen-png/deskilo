// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3964 (a) — ten plan and booking features of the reference business stop
// being switches a scenario shows "on": each is a state the seeds hold and
// the app's providers read, or an action a persona performs and finds the
// outcome of. The figures agree with the rest of the Demo.
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_plan_booking_journeys.dart';

void main() {
  test('the wall tablet greets a member who has a photo', () async {
    expect(await kioskPhotoState(), isTrue);
  });

  test('a held seat of the plan shows its occupant\'s photo', () async {
    expect(await planPhotoState(), isTrue);
  });

  test('the ground floor carries drawn decor', () async {
    expect(await planDecorState(), isTrue);
  });

  test('a drawn object is deleted and the plan keeps its seats', () async {
    expect(await planDeleteAction(), isTrue);
  });

  test('a place\'s QR code brings the member to that place', () async {
    expect(await spaceQrAction(), isTrue);
  });

  test('the working day is eight to six', () async {
    expect(await workingHoursState(), isTrue);
  });

  test('a level with one room is named by the level', () async {
    expect(await singleRoomState(), isTrue);
  });

  test('the booking rules are the workspace\'s own', () async {
    expect(await bookingPoliciesState(), isTrue);
  });

  test('the same booking is in the day, the week and the month', () async {
    expect(await calendarViewsAction(), isTrue);
  });

  test('a screenshot of a thread is recorded in the thread', () async {
    expect(await captureAction(), isTrue);
  });
}

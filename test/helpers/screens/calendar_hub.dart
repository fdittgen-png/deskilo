// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1864 C — the calendar hub pump, moved out of `test/features/calendar/calendar_hub_test.dart`:
// the accessibility matrix, the locale walk and the other suites that
// reuse it import this helper instead of a whole test file.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/calendar/calendar_item.dart';
import 'package:deskilo/features/workspace/domain/conversation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../fake_calendar_repository.dart';
import '../fake_floor_plan_repository.dart';
import '../mock_providers.dart';
import '../navigation.dart';

CalendarItem _item(CalendarKind kind, String id, DateTime at,
        {String member = 'member-1', CalendarLink? link, int? cents}) =>
    CalendarItem(
      kind: kind,
      id: id,
      at: at,
      memberId: member,
      title: 'Desk A1',
      link: link,
      amountCents: cents,
      currency: 'EUR',
    );

Future<({FakeCalendarRepository calendar, FakeWorkspaceRepository workspace})>
    pumpHub(
  WidgetTester tester, {
  bool admin = true,
  Map<String, dynamic> flags = const {},
  // #1183 — a test that is ABOUT the sideways layout has to start
  // there: turning the phone after the fact leaves one transient frame
  // whose overflow belongs to a widget already gone.
  //
  // #1583 — LOGICAL dp, at a ratio of 1, like every other pump helper
  // the matrix drives. The viewport is the same phone it always was;
  // what changed is that `size: Size(360, 800)` now means 360 dp
  // instead of 120, so the row measured a screen nobody holds and
  // blamed seven shared surfaces for it.
  Size size = const Size(360, 800),
}) async {
  final today = kTestNow;
  final calendar = FakeCalendarRepository()
    ..items.addAll([
      _item(CalendarKind.reservation, 'r1',
          DateTime.utc(today.year, today.month, today.day, 9),
          link: const ReservationLink('res-1')),
      _item(CalendarKind.message, 'm1',
          DateTime.utc(today.year, today.month, today.day, 10),
          link: const ConversationLink('conv-ana')),
      _item(CalendarKind.payment, 'p1',
          DateTime.utc(today.year, today.month, today.day, 11),
          link: const LedgerLink('2026-08'), cents: 4000),
      // Yesterday: must NOT show on a single-day selection.
      _item(CalendarKind.invoice, 'i-old',
          DateTime.utc(today.year, today.month, today.day - 1, 12)),
    ]);
  final workspace = FakeWorkspaceRepository.withWorkspace(featureFlags: flags)
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
    ..conversations.add(Conversation(
      id: 'conv-ana',
      kind: ConversationKind.direct,
      otherMemberId: 'member-2',
      lastAt: DateTime.utc(2026, 8, 27),
    ));
  if (!admin) {
    workspace.myMember =
        workspace.myMember.copyWith(isAdmin: false, isOwner: false);
  }
  // A phone-sized viewport: the filter row scrolls horizontally and the
  // feed vertically, and taps must land on what is on screen.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: standardTestOverrides(
      calendar: calendar,
      workspace: workspace,
      floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
    ),
    child: const DeskiloApp(),
  ));
  await tester.pumpAndSettle();
  await tapNavIcon(tester, Icons.calendar_month_outlined);
  return (calendar: calendar, workspace: workspace);
}

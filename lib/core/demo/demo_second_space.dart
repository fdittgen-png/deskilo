// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The demo's second space (Leipzig) as the repositories hold it.
//
// On a server, two spaces are rows of the same tables told apart by their
// workspace id. The in-memory repositories mostly hold ONE space's rows and
// answer them whatever id is asked, so the second space has repositories
// of its own and the Demo scope answers from them while it is the space
// being looked at (`demo_space_routing.dart`). The list of spaces is the
// one thing both share: `workspaces.workspaces` is the same list, so a
// change made to the Leipzig row is the change Me › Home lists.
import 'data/accessory_repository.dart';
import 'data/booking_right_reservations.dart';
import 'data/calendar_repository.dart';
import 'data/credit_repository.dart';
import 'data/decision_effects.dart';
import 'data/event_repository.dart';
import 'data/event_visibility.dart';
import 'data/floor_plan_repository.dart';
import 'data/money/demo_member_statement.dart';
import 'data/money_repository.dart';
import 'data/plan_resource_repository.dart';
import 'data/workspace_fields_repository.dart';
import 'data/workspace_repository.dart';
import 'data/workspace_roles_repository.dart';
import 'demo_space_listing.dart';
import 'demo_spaces.dart';
import 'seed/demo_calendar_seed.dart';
import 'seed/demo_second_space_money_seed.dart';
import 'seed/demo_second_space_seed.dart';

class DemoSecondSpaceData implements DemoSpaceParts {
  DemoSecondSpaceData._({
    required this.workspaces,
    required this.floorPlan,
    required this.reservations,
    required this.events,
    required this.calendar,
    required this.money,
  });

  /// #3846 — Leipzig's row and people, beside [home], whose list of spaces
  /// it joins: what the switcher needs at the start.
  static DemoSpaceListing list({
    required FakeWorkspaceRepository home,
    required DateTime now,
  }) {
    final space = FakeWorkspaceRepository(workspaces: home.workspaces);
    home.workspaces.add(demoSecondSpace());
    seedLeipzigPeople(space);
    seedLeipzigSpaceLife(space, now);
    return DemoSpaceListing(demoSecondSpaceId, space, home);
  }

  /// Seeds the rest of Leipzig over its [listing]. [actor] is the member the
  /// session acts as, read on every call.
  factory DemoSecondSpaceData.build({
    required DemoSpaceListing listing,
    required String Function() actor,
    required DateTime now,
  }) {
    final space = listing.workspaces;
    final plan = FakeFloorPlanRepository();
    seedLeipzigPlan(plan);
    final reservations = RightsCheckedReservationRepository(actor: actor);
    seedLeipzigBookings(reservations, now);
    // #3293 — Leipzig's requests are Leipzig's, stamped on its clock and
    // decided only by whom its rules name.
    final events = FakeEventRepository(
      actor: actor,
      workspaceId: demoSecondSpaceId,
      clock: () => now,
      decider: () => space.memberOf(actor()),
    );
    seedLeipzigRequests(events, now);
    final money = FakeMoneyRepository(events: events, clock: () => now);
    seedLeipzigMoney(money, now);
    // #3305 — each member reads their own statement.
    money.accountQueries.statementSource =
        demoStatementSource(space, reservations, demoSecondSpaceId,
            actor: actor);
    final calendar = FakeCalendarRepository(actor: actor);
    seedDemoCalendar(
      calendar,
      reservations: reservations,
      money: money,
      events: events,
    );
    wireDecisionEffects(events, reservations: reservations, workspaces: space, money: money, now: () => now);
    final data = DemoSecondSpaceData._(
      workspaces: space,
      floorPlan: plan,
      reservations: reservations,
      events: events,
      calendar: calendar,
      money: money,
    );
    events.viewerPermissions = demoViewerPermissions(space, data.roles, demoSecondSpaceId, actor);
    return data;
  }

  @override
  final FakeWorkspaceRepository workspaces;
  @override
  final FakeFloorPlanRepository floorPlan;
  @override
  final RightsCheckedReservationRepository reservations;
  @override
  final FakeEventRepository events;
  @override
  final FakeCalendarRepository calendar;
  @override
  final FakeMoneyRepository money;

  /// The features a new space keeps off, so these stay empty: they exist
  /// so that nothing of the main space answers for Leipzig.
  @override
  final credits = FakeCreditRepository();
  @override
  final accessories = FakeAccessoryRepository();
  @override
  final chargingStations = FakeChargingStationRepository();
  @override
  final fields = FakeWorkspaceFields();
  @override
  final roles = FakeWorkspaceRoles();
  @override
  late final planResources = FakePlanResourceRepository(floorPlan);

}

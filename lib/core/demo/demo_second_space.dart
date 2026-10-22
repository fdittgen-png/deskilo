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
import '../../features/workspace/domain/workspace.dart';
import 'data/accessory_repository.dart';
import 'data/calendar_repository.dart';
import 'data/credit_repository.dart';
import 'data/event_repository.dart';
import 'data/floor_plan_repository.dart';
import 'data/money_repository.dart';
import 'data/plan_resource_repository.dart';
import 'data/reservation_repository.dart';
import 'data/workspace_fields_repository.dart';
import 'data/workspace_repository.dart';
import 'data/workspace_roles_repository.dart';
import 'seed/demo_calendar_seed.dart';
import 'seed/demo_second_space_money_seed.dart';
import 'seed/demo_second_space_seed.dart';

class DemoSecondSpaceData {
  DemoSecondSpaceData._({
    required this.workspaces,
    required this.floorPlan,
    required this.reservations,
    required this.events,
    required this.calendar,
    required this.money,
  });

  /// Seeds the Leipzig space beside [home], whose list of spaces it joins.
  /// [actor] is the member the session acts as, read on every call.
  factory DemoSecondSpaceData.build({
    required FakeWorkspaceRepository home,
    required String Function() actor,
    required DateTime now,
  }) {
    final space = FakeWorkspaceRepository(workspaces: home.workspaces);
    home.workspaces.add(demoSecondSpace());
    seedLeipzigPeople(space);
    seedLeipzigSpaceLife(space, now);
    final plan = FakeFloorPlanRepository();
    seedLeipzigPlan(plan);
    final reservations = FakeReservationRepository(actor: actor);
    seedLeipzigBookings(reservations, now);
    final events = FakeEventRepository(actor: actor);
    seedLeipzigRequests(events, now);
    final money = FakeMoneyRepository(events: events);
    seedLeipzigMoney(money, now);
    final calendar = FakeCalendarRepository(actor: actor);
    seedDemoCalendar(
      calendar,
      reservations: reservations,
      money: money,
      events: events,
    );
    return DemoSecondSpaceData._(
      workspaces: space,
      floorPlan: plan,
      reservations: reservations,
      events: events,
      calendar: calendar,
      money: money,
    );
  }

  final FakeWorkspaceRepository workspaces;
  final FakeFloorPlanRepository floorPlan;
  final FakeReservationRepository reservations;
  final FakeEventRepository events;
  final FakeCalendarRepository calendar;
  final FakeMoneyRepository money;

  /// The features a new space keeps off, so these stay empty: they exist
  /// so that nothing of the main space answers for Leipzig.
  final credits = FakeCreditRepository();
  final accessories = FakeAccessoryRepository();
  final chargingStations = FakeChargingStationRepository();
  final fields = FakeWorkspaceFields();
  final roles = FakeWorkspaceRoles();
  late final planResources = FakePlanResourceRepository(floorPlan);

  /// The Leipzig row while the persona is not a member there.
  Workspace? _parked;

  /// Looks at Leipzig as [memberId]: their membership becomes "mine"
  /// here and in [home]'s list of memberships. A persona with no
  /// membership in Leipzig does not see the space at all.
  void viewAs(String memberId, FakeWorkspaceRepository home) {
    final rows = [workspaces.myMember, ...workspaces.otherMembers];
    final mine = rows.where((m) => m.id == memberId).firstOrNull;
    home.extraMyMemberships.removeWhere(
      (m) => m.workspaceId == demoSecondSpaceId,
    );
    final listed = home.workspaces.indexWhere((w) => w.id == demoSecondSpaceId);
    if (mine == null) {
      if (listed >= 0) _parked = home.workspaces.removeAt(listed);
      return;
    }
    workspaces.myMember = mine;
    workspaces.otherMembers
      ..clear()
      ..addAll(rows.where((m) => m.id != mine.id));
    home.extraMyMemberships.add(mine);
    if (listed < 0 && _parked != null) home.workspaces.add(_parked!);
    _parked = null;
  }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The demo's third space (London) as the repositories hold it, built like the
// second (`demo_second_space.dart`): repositories of its own, answered by the
// Demo scope only while this space is the one looked at, so nothing of the
// French or German space answers for it and a filing here cannot touch
// either of them. The list of spaces is the one thing all share.
import 'dart:async';

import '../../features/workspace/domain/workspace.dart';
import 'data/accessory_repository.dart';
import 'data/calendar_repository.dart';
import 'data/credit_repository.dart';
import 'data/demo_hmrc_repository.dart';
import 'data/event_repository.dart';
import 'data/floor_plan_repository.dart';
import 'data/money_repository.dart';
import 'data/plan_resource_repository.dart';
import 'data/reservation_repository.dart';
import 'data/workspace_fields_repository.dart';
import 'data/workspace_repository.dart';
import 'data/workspace_roles_repository.dart';
import 'seed/demo_london_seed.dart';

class DemoLondonData {
  DemoLondonData._({
    required this.workspaces,
    required this.floorPlan,
    required this.reservations,
    required this.events,
    required this.calendar,
    required this.money,
    required this.hmrc,
  });

  /// Seeds the London space beside [home], whose list of spaces it joins.
  factory DemoLondonData.build({
    required FakeWorkspaceRepository home,
    required String Function() actor,
    required DateTime now,
    DemoHmrcScript? hmrcScript,
  }) {
    final space = FakeWorkspaceRepository(workspaces: home.workspaces);
    home.workspaces.add(demoLondonSpace());
    seedLondonPeople(space);
    final events = FakeEventRepository(actor: actor);
    final money = FakeMoneyRepository(events: events);
    seedLondonMoney(money, now);
    // The return of the closed quarter, prepared by the engine every space
    // uses; its figures are the invoices', not a number typed here.
    final quarter = demoLondonQuarter(now);
    // (The preparation has no await in it: the return is there when it returns.)
    unawaited(money.taxReporting.saveVatDeclaration(
      workspaceId: demoLondonSpaceId,
      periodStart: quarter.start,
      periodEnd: quarter.end,
    ));
    return DemoLondonData._(
      workspaces: space,
      floorPlan: FakeFloorPlanRepository(),
      reservations: FakeReservationRepository(actor: actor),
      events: events,
      calendar: FakeCalendarRepository(actor: actor),
      money: money,
      hmrc: DemoHmrcRepository(
        money: money,
        workspaces: space,
        today: now,
        script: hmrcScript,
      ),
    );
  }

  final FakeWorkspaceRepository workspaces;
  final FakeFloorPlanRepository floorPlan;
  final FakeReservationRepository reservations;
  final FakeEventRepository events;
  final FakeCalendarRepository calendar;
  final FakeMoneyRepository money;
  final DemoHmrcRepository hmrc;

  /// The features a new space keeps off, so these stay empty: they exist so
  /// that nothing of another space answers for London.
  final credits = FakeCreditRepository();
  final accessories = FakeAccessoryRepository();
  final chargingStations = FakeChargingStationRepository();
  final fields = FakeWorkspaceFields();
  final roles = FakeWorkspaceRoles();
  late final planResources = FakePlanResourceRepository(floorPlan);

  /// The London row while the persona is not a member there.
  Workspace? _parked;

  /// Looks at London as [memberId]: their membership becomes "mine" here and
  /// in [home]'s list of memberships. A persona with no membership here (the
  /// kiosk tablet) does not see the space at all.
  void viewAs(String memberId, FakeWorkspaceRepository home) {
    final rows = [workspaces.myMember, ...workspaces.otherMembers];
    final mine = rows.where((m) => m.id == memberId).firstOrNull;
    home.extraMyMemberships.removeWhere((m) => m.workspaceId == demoLondonSpaceId);
    final listed = home.workspaces.indexWhere((w) => w.id == demoLondonSpaceId);
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

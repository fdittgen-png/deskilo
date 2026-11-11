// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The demo's third space (London) as the repositories hold it, built like the
// second (`demo_second_space.dart`): repositories of its own, answered by the
// Demo scope only while this space is the one looked at, so nothing of the
// French or German space answers for it and a filing here cannot touch
// either of them. The list of spaces is the one thing all share.
import 'dart:async';

import '../../features/plan/domain/seat.dart';
import '../../features/workspace/domain/workspace.dart';
import 'data/accessory_repository.dart';
import 'data/booking_right_reservations.dart';
import 'data/calendar_repository.dart';
import 'data/city_floor_plan_repository.dart';
import 'data/credit_repository.dart';
import 'data/decision_effects.dart';
import 'data/demo_hmrc_repository.dart';
import 'data/event_repository.dart';
import 'data/event_visibility.dart';
import 'data/floor_plan_repository.dart';
import 'data/money/demo_member_statement.dart';
import 'data/money_repository.dart';
import 'data/plan_resource_repository.dart';
import 'data/workspace_fields_repository.dart';
import 'data/workspace_repository.dart';
import 'data/workspace_roles_repository.dart';
import 'seed/demo_calendar_seed.dart';
import 'seed/demo_city_money_seed.dart';
import 'seed/demo_city_plan_seed.dart';
import 'seed/demo_city_usage_seed.dart';
import 'seed/demo_city_workflow_seed.dart';
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
    final plan = CityFloorPlanRepository();
    seedCityPlans(
      plan,
      workspaceId: demoLondonSpaceId,
      prefix: 'uk',
      sites: [demoLondonSiteId, 'uk-site-islington', 'uk-site-hackney'],
      mainFloorOffices: [3, 12, 3, 3],
    );
    final reservations = RightsCheckedReservationRepository(actor: actor);
    reservations.resourceSeatIds.addAll(
      plan.seats
          .where((seat) => seat.resourceKind != ResourceKind.seat)
          .map((seat) => seat.id),
    );
    final siteRentals = [
      (
        siteId: 'uk-site-islington',
        memberId: 'uk-member-82',
        month: DateTime(now.year - 2, 2),
      ),
      (
        siteId: 'uk-site-hackney',
        memberId: 'uk-member-82',
        month: DateTime(now.year - 1, 3),
      ),
    ];
    seedCityBookings(reservations, plan, (
      workspaceId: demoLondonSpaceId,
      prefix: 'uk',
      now: now,
      years: 3,
      timeZone: 'Europe/London',
      members: [
        for (final m in [space.myMember, ...space.otherMembers])
          if (m.id != 'uk-member-82') m.id,
      ],
      partTimeMembers: {
        for (final m in [space.myMember, ...space.otherMembers])
          if (m.subscriptionPct < 100) m.id,
      },
      siteRentals: siteRentals,
    ));
    final events = FakeEventRepository(
      actor: actor,
      workspaceId: demoLondonSpaceId,
      clock: () => now,
      decider: () => space.memberOf(actor()),
    );
    seedCityDecisions(events, 'uk', now);
    final money = FakeMoneyRepository(events: events)
      ..invoiceCommands.currency = 'GBP';
    seedCityExpenses(money, demoLondonSpaceId, 'uk', now);
    seedLondonMoney(money, now);
    // The return of the closed quarter, prepared by the engine every space
    // uses; its figures are the invoices', not a number typed here.
    final quarter = demoLondonQuarter(now);
    seedCityMoney(money, space, (
      workspaceId: demoLondonSpaceId,
      prefix: 'uk',
      name: 'Camden Yard Cowork',
      currency: 'GBP',
      now: now,
      years: 3,
      hourlyBookings: const [],
      vatPercent: 20,
      siteRentals: siteRentals,
    ));
    // (The preparation has no await in it: the return is there when it returns.)
    unawaited(
      money.taxReporting.saveVatDeclaration(
        workspaceId: demoLondonSpaceId,
        periodStart: quarter.start,
        periodEnd: quarter.end,
      ),
    );
    seedCityUsage(money, reservations.reservations);
    final calendar = FakeCalendarRepository(actor: actor);
    seedDemoCalendar(
      calendar,
      reservations: reservations,
      money: money,
      events: events,
      currency: 'GBP',
    );
    wireDecisionEffects(events, reservations: reservations, workspaces: space, money: money, now: () => now);
    final city = DemoLondonData._(
      workspaces: space,
      floorPlan: plan,
      reservations: reservations,
      events: events,
      calendar: calendar,
      money: money,
      hmrc: DemoHmrcRepository(
        money: money,
        workspaces: space,
        today: now,
        script: hmrcScript,
        initiallyUnconfirmed: money.vatDeclarations.single.id,
      ),
    );
    seedCityPeopleWorkflows((
      space: space, fields: city.fields, roles: city.roles,
      credits: city.credits, workspaceId: demoLondonSpaceId, prefix: 'uk', now: now,
    ));
    city.accessories.seedSmallCatalog(workspaceId: demoLondonSpaceId);
    seedCityCharger(city.chargingStations, 'uk');
    events.viewerPermissions = demoViewerPermissions(space, city.roles, demoLondonSpaceId, actor);
    // #3305 — each member reads their own statement, as member_statement.
    city.money.accountQueries.statementSource =
        demoStatementSource(city.workspaces, city.reservations, demoLondonSpaceId, actor: actor, credits: city.credits);
    return city;
  }

  final FakeWorkspaceRepository workspaces;
  final FakeFloorPlanRepository floorPlan;
  final RightsCheckedReservationRepository reservations;
  final FakeEventRepository events;
  final FakeCalendarRepository calendar;
  final FakeMoneyRepository money;
  final DemoHmrcRepository hmrc;

  /// Isolated stores for capabilities that do not yet have city data.
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
    home.extraMyMemberships.removeWhere(
      (m) => m.workspaceId == demoLondonSpaceId,
    );
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

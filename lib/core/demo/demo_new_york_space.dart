// SPDX-License-Identifier: AGPL-3.0-or-later
//
// New York has its own in-memory repositories and a shared workspace list.
import '../../features/plan/domain/seat.dart';
import '../../features/workspace/domain/booking_granularity.dart';
import 'data/accessory_repository.dart';
import 'data/booking_right_reservations.dart';
import 'data/calendar_repository.dart';
import 'data/city_floor_plan_repository.dart';
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
import 'seed/demo_city_money_seed.dart';
import 'seed/demo_city_plan_seed.dart';
import 'seed/demo_city_usage_seed.dart';
import 'seed/demo_city_workflow_seed.dart';
import 'seed/demo_new_york_seed.dart';

class DemoNewYorkData implements DemoSpaceParts {
  DemoNewYorkData._({
    required this.workspaces,
    required this.floorPlan,
    required this.reservations,
    required this.events,
    required this.calendar,
    required this.money,
  });

  /// #3846 — New York's row and people, beside [home], whose list of spaces
  /// it joins: what the switcher needs at the start.
  static DemoSpaceListing list({required FakeWorkspaceRepository home}) {
    final space = FakeWorkspaceRepository(workspaces: home.workspaces);
    home.workspaces.add(demoNewYorkSpace());
    seedNewYorkPeople(space);
    space.bookingGranularities[demoNewYorkSpaceId] =
        BookingGranularity.minutes60;
    return DemoSpaceListing(demoNewYorkSpaceId, space, home);
  }

  /// Seeds the rest of New York over its [listing]. [actor] is the member the
  /// session acts as, read on every call.
  factory DemoNewYorkData.build({
    required DemoSpaceListing listing,
    required String Function() actor,
    required DateTime now,
  }) {
    final space = listing.workspaces;
    final plan = CityFloorPlanRepository();
    seedCityPlans(
      plan,
      workspaceId: demoNewYorkSpaceId,
      prefix: 'ny',
      sites: [
        'ny-site-main',
        'ny-site-brooklyn',
        'ny-site-queens',
        'ny-site-bronx',
        'ny-site-harlem',
      ],
      mainFloorOffices: [3, 3, 3, 3],
      hourly: true,
    );
    final reservations = RightsCheckedReservationRepository(actor: actor)
      ..granularity = BookingGranularity.minutes60;
    reservations.resourceSeatIds.addAll(
      plan.seats
          .where((seat) => seat.resourceKind != ResourceKind.seat)
          .map((seat) => seat.id),
    );
    seedCityBookings(reservations, plan, (
      workspaceId: demoNewYorkSpaceId,
      prefix: 'ny',
      now: now,
      years: 4,
      timeZone: 'America/New_York',
      siteRentals: const [],
      members: [
        for (final m in [space.myMember, ...space.otherMembers]) m.id,
      ],
      partTimeMembers: const {},
    ));
    final events = FakeEventRepository(
      actor: actor,
      workspaceId: demoNewYorkSpaceId,
      clock: () => now,
      decider: () => space.memberOf(actor()),
    );
    seedCityDecisions(events, 'ny', now);
    final money = FakeMoneyRepository(events: events)
      ..invoiceCommands.currency = 'USD';
    seedCityExpenses(money, demoNewYorkSpaceId, 'ny', now);
    seedCityMoney(money, space, (
      workspaceId: demoNewYorkSpaceId,
      prefix: 'ny',
      name: 'Hudson Cooperative Workspaces',
      currency: 'USD',
      now: now,
      years: 4,
      vatPercent: 0,
      siteRentals: const [],
      hourlyBookings: reservations.reservations,
    ));
    seedCityUsage(money, reservations.reservations);
    final calendar = FakeCalendarRepository(actor: actor);
    seedDemoCalendar(
      calendar,
      reservations: reservations,
      money: money,
      events: events,
      currency: 'USD',
    );
    wireDecisionEffects(events, reservations: reservations, workspaces: space, money: money, now: () => now);
    final city = DemoNewYorkData._(
      workspaces: space,
      floorPlan: plan,
      reservations: reservations,
      events: events,
      calendar: calendar,
      money: money,
    );
    seedCityPeopleWorkflows((
      space: space, fields: city.fields, roles: city.roles,
      credits: city.credits, workspaceId: demoNewYorkSpaceId, prefix: 'ny', now: now,
    ));
    city.accessories.seedSmallCatalog(workspaceId: demoNewYorkSpaceId);
    seedCityCharger(city.chargingStations, 'ny');
    events.viewerPermissions = demoViewerPermissions(space, city.roles, demoNewYorkSpaceId, actor);
    // #3305 — each member reads their own statement, as member_statement.
    city.money.accountQueries.statementSource =
        demoStatementSource(city.workspaces, city.reservations, demoNewYorkSpaceId, actor: actor, credits: city.credits);
    return city;
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

  /// Isolated stores for capabilities that do not yet have city data.
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

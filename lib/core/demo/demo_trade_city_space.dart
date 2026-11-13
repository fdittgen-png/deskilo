// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3832 — a trade city (Zurich, Milan) as the repositories hold it: its own
// in-memory stores beside the main space's, a shared list of spaces, and
// every record derived from the city's [DemoTradeCity] facts.
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
import 'seed/demo_trade_city_seed.dart';

class DemoTradeCityData implements DemoSpaceParts {
  DemoTradeCityData._({
    required this.city,
    required this.workspaces,
    required this.floorPlan,
    required this.reservations,
    required this.events,
    required this.calendar,
    required this.money,
  });

  /// #3846 — [city]'s row and people, beside [home], whose list of spaces it
  /// joins: what the switcher needs at the start.
  static DemoSpaceListing list({
    required DemoTradeCity city,
    required FakeWorkspaceRepository home,
  }) {
    final space = FakeWorkspaceRepository(workspaces: home.workspaces);
    home.workspaces.add(city.workspace());
    city.seedPeople(space);
    space.bookingGranularities[city.id] = BookingGranularity.minutes60;
    return DemoSpaceListing(city.id, space, home);
  }

  /// Seeds the rest of [city] over its [listing]. [actor] is the member the
  /// session acts as, read on every call.
  factory DemoTradeCityData.build({
    required DemoTradeCity city,
    required DemoSpaceListing listing,
    required String Function() actor,
    required DateTime now,
  }) {
    final space = listing.workspaces;
    final plan = CityFloorPlanRepository();
    seedCityPlans(
      plan,
      workspaceId: city.id,
      prefix: city.prefix,
      sites: city.siteIds,
      mainFloorOffices: [2],
    );
    final reservations = RightsCheckedReservationRepository(actor: actor)
      ..granularity = BookingGranularity.minutes60;
    reservations.resourceSeatIds.addAll(
      plan.seats
          .where((seat) => seat.resourceKind != ResourceKind.seat)
          .map((seat) => seat.id),
    );
    final everyone = [space.myMember, ...space.otherMembers];
    seedCityBookings(reservations, plan, (
      workspaceId: city.id,
      prefix: city.prefix,
      now: now,
      years: DemoTradeCity.years,
      timeZone: city.timezone,
      siteRentals: const [],
      members: [for (final m in everyone) m.id],
      partTimeMembers: {
        for (final m in everyone)
          if (m.subscriptionPct < 100) m.id,
      },
    ));
    final events = FakeEventRepository(
      actor: actor,
      workspaceId: city.id,
      clock: () => now,
      decider: () => space.memberOf(actor()),
    );
    seedCityDecisions(events, city.prefix, now);
    final money = FakeMoneyRepository(events: events, clock: () => now)
      ..invoiceCommands.currency = city.currency;
    seedCityExpenses(money, city.id, city.prefix, now);
    seedCityMoney(money, space, (
      workspaceId: city.id,
      prefix: city.prefix,
      name: city.name,
      currency: city.currency,
      now: now,
      years: DemoTradeCity.years,
      vatPercent: city.vatPercent,
      siteRentals: const [],
      hourlyBookings: const [],
    ));
    seedCityUsage(money, reservations.reservations);
    final calendar = FakeCalendarRepository(actor: actor);
    seedDemoCalendar(
      calendar,
      reservations: reservations,
      money: money,
      events: events,
      currency: city.currency,
    );
    wireDecisionEffects(
      events,
      reservations: reservations,
      workspaces: space,
      money: money,
      now: () => now,
    );
    final data = DemoTradeCityData._(
      city: city,
      workspaces: space,
      floorPlan: plan,
      reservations: reservations,
      events: events,
      calendar: calendar,
      money: money,
    );
    seedCityPeopleWorkflows((
      space: space,
      fields: data.fields,
      roles: data.roles,
      credits: data.credits,
      workspaceId: city.id,
      prefix: city.prefix,
      now: now,
    ));
    data.accessories.seedSmallCatalog(workspaceId: city.id);
    seedCityCharger(data.chargingStations, city.prefix);
    events.viewerPermissions = demoViewerPermissions(
      space,
      data.roles,
      city.id,
      actor,
    );
    // #3305 — each member reads their own statement, as member_statement.
    data.money.accountQueries.statementSource = demoStatementSource(
      data.workspaces,
      data.reservations,
      city.id,
      actor: actor,
      credits: data.credits,
    );
    return data;
  }

  final DemoTradeCity city;
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

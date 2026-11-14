// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3863 — the Demo's practice (Berlin) as the repositories hold it: a
// business without places. Its floor plan is empty and it has no booking;
// its money is three years of monthly invoices for its own services, from
// the generator the city spaces use, with the practice's words.
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
import 'demo_space_ids.dart';
import 'demo_space_listing.dart';
import 'demo_spaces.dart';
import 'seed/demo_calendar_seed.dart';
import 'seed/demo_city_money_seed.dart';
import 'seed/demo_practice_seed.dart';

class DemoPracticeData implements DemoSpaceParts {
  DemoPracticeData._({
    required this.workspaces,
    required this.reservations,
    required this.events,
    required this.calendar,
    required this.money,
  });

  /// The practice's row and people, beside [home], whose list of spaces it
  /// joins: what the switcher needs at the start.
  static DemoSpaceListing list({required FakeWorkspaceRepository home}) {
    final space = FakeWorkspaceRepository(workspaces: home.workspaces);
    home.workspaces.add(demoPracticeSpace());
    seedPracticePeople(space);
    return DemoSpaceListing(demoPracticeSpaceId, space, home);
  }

  /// The years of invoices the practice holds, as London's.
  static const years = 3;

  /// Seeds the rest of the practice over its [listing]. [actor] is the
  /// member the session acts as, read on every call.
  factory DemoPracticeData.build({
    required DemoSpaceListing listing,
    required String Function() actor,
    required DateTime now,
  }) {
    final space = listing.workspaces;
    final reservations = RightsCheckedReservationRepository(actor: actor);
    final events = FakeEventRepository(
      actor: actor,
      workspaceId: demoPracticeSpaceId,
      clock: () => now,
      decider: () => space.memberOf(actor()),
    );
    final money = FakeMoneyRepository(events: events, clock: () => now)
      ..invoiceCommands.currency = 'EUR';
    seedCityMoney(money, space, (
      workspaceId: demoPracticeSpaceId,
      prefix: 'practice',
      name: demoPracticeName,
      currency: 'EUR',
      now: now,
      years: years,
      hourlyBookings: const [],
      vatPercent: 19,
      siteRentals: const [],
    ), words: demoPracticeMoneyWords);
    money.accountQueries.statementSource = demoStatementSource(
      space,
      reservations,
      demoPracticeSpaceId,
      actor: actor,
    );
    final calendar = FakeCalendarRepository(actor: actor);
    seedDemoCalendar(
      calendar,
      reservations: reservations,
      money: money,
      events: events,
    );
    wireDecisionEffects(
      events,
      reservations: reservations,
      workspaces: space,
      money: money,
      now: () => now,
    );
    final data = DemoPracticeData._(
      workspaces: space,
      reservations: reservations,
      events: events,
      calendar: calendar,
      money: money,
    );
    events.viewerPermissions = demoViewerPermissions(
      space,
      data.roles,
      demoPracticeSpaceId,
      actor,
    );
    return data;
  }

  @override
  final FakeWorkspaceRepository workspaces;

  /// No floor plan: the practice has no places.
  @override
  final floorPlan = FakeFloorPlanRepository();
  @override
  final RightsCheckedReservationRepository reservations;
  @override
  final FakeEventRepository events;
  @override
  final FakeCalendarRepository calendar;
  @override
  final FakeMoneyRepository money;

  /// What a practice does not have stays empty, so nothing of another space
  /// answers for it.
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

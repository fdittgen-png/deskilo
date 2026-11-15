// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4005 — the house abroad the Demo adds (Atelier Kraków) as the repositories
// hold it: a business made today. Nothing has happened in it yet: no place,
// no booking, no invoice. Its listing is dormant until the visitor adds a
// house abroad; then the head's services and packages arrive in its money,
// inactive, to be priced.
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
import 'seed/demo_house_seed.dart';

class DemoHouseData implements DemoSpaceParts {
  DemoHouseData._({
    required this.workspaces,
    required this.reservations,
    required this.events,
    required this.calendar,
    required this.money,
  });

  /// The house's row and owner, beside [home], dormant: nowhere to be seen
  /// until it is revealed.
  static DemoSpaceListing list({required FakeWorkspaceRepository home}) {
    final space = FakeWorkspaceRepository(workspaces: home.workspaces);
    home.workspaces.add(demoHouseSpace());
    seedHousePeople(space);
    return DemoSpaceListing(demoHouseSpaceId, space, home)..dormant = true;
  }

  /// Seeds the house over its [listing]: empty. [actor] is the member the
  /// session acts as, read on every call.
  factory DemoHouseData.build({
    required DemoSpaceListing listing,
    required String Function() actor,
    required DateTime now,
  }) {
    final space = listing.workspaces;
    final reservations = RightsCheckedReservationRepository(actor: actor);
    final events = FakeEventRepository(
      actor: actor,
      workspaceId: demoHouseSpaceId,
      clock: () => now,
      decider: () => space.memberOf(actor()),
    );
    final money = FakeMoneyRepository(events: events, clock: () => now)
      ..invoiceCommands.currency = demoHouseCurrency
      // A new business: no catalogue of its own until the head's arrives.
      ..services.clear()
      ..packages.clear();
    money.accountQueries.statementSource = demoStatementSource(
      space,
      reservations,
      demoHouseSpaceId,
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
    final data = DemoHouseData._(
      workspaces: space,
      reservations: reservations,
      events: events,
      calendar: calendar,
      money: money,
    );
    events.viewerPermissions = demoViewerPermissions(
      space,
      data.roles,
      demoHouseSpaceId,
      actor,
    );
    return data;
  }

  @override
  final FakeWorkspaceRepository workspaces;

  /// No floor plan: the house has no place yet.
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

  /// What a new house does not have stays empty, so nothing of another
  /// space answers for it.
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

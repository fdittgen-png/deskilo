// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4365 -- the Épicerie du Marché as the repositories hold it: a shop without places to book. Its floor plan is
// empty and nothing is booked; its goods ledger is the Demo's stock providers' (kept per business), and its
// money is empty beside it.
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
import 'seed/demo_shop_seed.dart';

class DemoShopData implements DemoSpaceParts {
  DemoShopData._({
    required this.workspaces,
    required this.reservations,
    required this.events,
    required this.calendar,
    required this.money,
  });

  /// The business's row and its owner, beside [home], whose list of spaces it
  /// joins.
  static DemoSpaceListing list({required FakeWorkspaceRepository home}) {
    final space = FakeWorkspaceRepository(workspaces: home.workspaces);
    home.workspaces.add(demoShopSpace());
    seedShopPeople(space);
    return DemoSpaceListing(demoShopSpaceId, space, home);
  }

  /// Seeds the rest of the business over its [listing]. [actor] is the member
  /// the session acts as, read on every call.
  factory DemoShopData.build({
    required DemoSpaceListing listing,
    required String Function() actor,
    required DateTime now,
  }) {
    final space = listing.workspaces;
    final reservations = RightsCheckedReservationRepository(actor: actor, clock: () => now);
    final events = FakeEventRepository(
      actor: actor,
      workspaceId: demoShopSpaceId,
      clock: () => now,
      decider: () => space.memberOf(actor()),
    );
    final money = FakeMoneyRepository(events: events, clock: () => now)
      ..invoiceCommands.currency = 'EUR'
      ..standaloneInvoiceCommands.currency = 'EUR'
      ..paymentGateway.standIn = true;
    money.accountQueries.statementSource = demoStatementSource(
      space,
      reservations,
      demoShopSpaceId,
      actor: actor,
    );
    final calendar = FakeCalendarRepository(actor: actor);
    seedDemoCalendar(calendar, reservations: reservations, money: money, events: events);
    wireDecisionEffects(
      events,
      reservations: reservations,
      workspaces: space,
      money: money,
      now: () => now,
    );
    final data = DemoShopData._(
      workspaces: space,
      reservations: reservations,
      events: events,
      calendar: calendar,
      money: money,
    );
    events.viewerPermissions = demoViewerPermissions(
      space,
      data.roles,
      demoShopSpaceId,
      actor,
    );
    return data;
  }

  @override
  final FakeWorkspaceRepository workspaces;

  /// No floor plan: the business has no places.
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

  /// What a shop does not have stays empty.
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

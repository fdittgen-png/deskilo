// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3302 — the main space's development twin as the repositories hold it.
//
// A twin is a workspace of its own in the same pair (0185): it was created
// with a copy of its production's configuration, every production member is
// also its member (members_mirror_to_dev, ADR 0019: prod ⊆ dev), and its
// bookings, requests and money are its own — what is tried there never
// reaches production except through a deployment. So the twin gets its own
// stores: a copy of the production plan, the production cast mirrored, and
// empty activity. The deployment journal is the pair's, shared by both sides.
import '../../features/plan/domain/desk.dart';
import '../../features/plan/domain/level.dart';
import '../../features/plan/domain/office.dart';
import '../../features/plan/domain/seat.dart';
import '../../features/workspace/domain/workspace_role.dart';
import 'data/accessory_repository.dart';
import 'data/booking_right_reservations.dart';
import 'data/calendar_repository.dart';
import 'data/credit_repository.dart';
import 'data/decision_effects.dart';
import 'data/einvoice_inbox_repository.dart';
import 'data/event_repository.dart';
import 'data/event_visibility.dart';
import 'data/floor_plan_repository.dart';
import 'data/money/demo_member_statement.dart';
import 'data/money_repository.dart';
import 'data/plan_resource_repository.dart';
import 'data/purchase_repository.dart';
import 'data/supplier_repository.dart';
import 'data/workspace_fields_repository.dart';
import 'data/workspace_repository.dart';
import 'data/workspace_roles_repository.dart';
import 'demo_space_listing.dart';
import 'demo_spaces.dart';
import 'seed/demo_calendar_seed.dart';
import 'seed/demo_purchase_seed.dart';
import 'seed/demo_twin_seed.dart';

/// #3846 — the twin's listing with the copy of production it is built from.
class DemoTwinSource {
  const DemoTwinSource({
    required this.listing,
    required this.levels,
    required this.offices,
    required this.desks,
    required this.seats,
    required this.levelSites,
    required this.roles,
    required this.assignments,
  });

  final DemoSpaceListing listing;
  final List<Level> levels;
  final List<Office> offices;
  final List<Desk> desks;
  final List<Seat> seats;
  final Map<String, String?> levelSites;
  final List<WorkspaceRole> roles;
  final Map<String, List<String>> assignments;
}

class DemoTwinData implements DemoSpaceParts {
  DemoTwinData._({
    required this.workspaces,
    required this.floorPlan,
    required this.reservations,
    required this.events,
    required this.calendar,
    required this.money,
    required this.purchasing,
  });

  /// #3846 — the twin's row and people beside [home] (whose list already
  /// holds its row, seeded by `seedDemoTwin`), and what its plan and roles are
  /// copied from: taken now, so the twin is the copy of production as seeded
  /// whenever it is built, not as a visitor has since left it.
  static DemoTwinSource list({
    required FakeWorkspaceRepository home,
    required FakeFloorPlanRepository productionPlan,
    required FakeWorkspaceRoles productionRoles,
  }) {
    const ws = demoTwinSpaceId;
    final space = FakeWorkspaceRepository(workspaces: home.workspaces)
      ..myMember = home.myMember.copyWith(workspaceId: ws)
      ..memberNames = {...home.memberNames}
      ..memberEmails = {...home.memberEmails}
      ..otherMembers.addAll([for (final m in home.otherMembers) m.copyWith(workspaceId: ws)]);
    return DemoTwinSource(
      listing: DemoSpaceListing(ws, space, home),
      levels: [for (final l in productionPlan.levels) if (l.workspaceId == 'ws-1') l],
      offices: [for (final o in productionPlan.offices) if (o.workspaceId == 'ws-1') o],
      desks: [for (final d in productionPlan.desks) if (d.workspaceId == 'ws-1') d],
      seats: [for (final s in productionPlan.seats) if (s.workspaceId == 'ws-1') s],
      levelSites: {...productionPlan.levelSites},
      roles: [...productionRoles.roles],
      assignments: {
        for (final e in productionRoles.assignments.entries) e.key: [...e.value],
      },
    );
  }

  /// The twin over its [source], its plan copied once.
  factory DemoTwinData.build({
    required DemoTwinSource source,
    required String Function() actor,
    required DateTime now,
  }) {
    const ws = demoTwinSpaceId;
    final space = source.listing.workspaces;
    final plan = FakeFloorPlanRepository();
    plan.levels.addAll([for (final l in source.levels) l.copyWith(workspaceId: ws)]);
    plan.offices.addAll([for (final o in source.offices) o.copyWith(workspaceId: ws)]);
    plan.desks.addAll([for (final d in source.desks) d.copyWith(workspaceId: ws)]);
    plan.seats.addAll([for (final s in source.seats) s.copyWith(workspaceId: ws)]);
    plan.levelSites.addAll(source.levelSites);
    final reservations = RightsCheckedReservationRepository(actor: actor);
    // #3293 — the twin's requests are stamped on the session clock and
    // decided and read only as its own rules and rights allow.
    final events = FakeEventRepository(
      actor: actor,
      workspaceId: ws,
      clock: () => now,
      decider: () => space.memberOf(actor()),
    );
    final money = FakeMoneyRepository(events: events);
    final calendar = FakeCalendarRepository(actor: actor);
    seedDemoCalendar(calendar, reservations: reservations, money: money, events: events);
    wireDecisionEffects(events, reservations: reservations, workspaces: space, money: money, now: () => now);
    final data = DemoTwinData._(
      workspaces: space,
      floorPlan: plan,
      reservations: reservations,
      events: events,
      calendar: calendar,
      money: money,
      purchasing: DemoPurchasing(
        suppliers: FakeSupplierRepository(),
        inbox: FakeEInvoiceInboxRepository(),
        // #3797 — the twin's own purchases, empty: none of production's.
        purchases: FakePurchaseRepository(
          actor: actor,
          workspaceId: demoTwinSpaceId,
        ),
      ),
    );
    // The roles are configuration, copied once with the rest of it; the
    // effective rights are then the twin's own.
    data.roles.roles.addAll(source.roles);
    for (final e in source.assignments.entries) {
      data.roles.assignments[e.key] = [...e.value];
    }
    events.viewerPermissions = demoViewerPermissions(space, data.roles, ws, actor);
    // #3305 — each member reads their own statement, as member_statement.
    data.money.accountQueries.statementSource =
        demoStatementSource(data.workspaces, data.reservations, ws, actor: actor, credits: data.credits);
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

  /// Its own (empty) suppliers, received invoices and purchases.
  final DemoPurchasing purchasing;

  @override
  final credits = FakeCreditRepository();
  @override
  final accessories = FakeAccessoryRepository();
  @override
  final chargingStations = FakeChargingStationRepository();
  @override
  final fields = FakeWorkspaceFields();
  @override
  @override
  final roles = FakeWorkspaceRoles();
  @override
  late final planResources = FakePlanResourceRepository(floorPlan);
}

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
import '../../features/workspace/domain/workspace.dart';
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
import 'seed/demo_calendar_seed.dart';
import 'seed/demo_purchase_seed.dart';
import 'seed/demo_twin_seed.dart';

class DemoTwinData {
  DemoTwinData._({
    required this.workspaces,
    required this.floorPlan,
    required this.reservations,
    required this.events,
    required this.calendar,
    required this.money,
    required this.purchasing,
  });

  /// The twin beside [home] (whose list already holds its row, seeded by
  /// `seedDemoTwin`), its plan copied from [productionPlan] once.
  factory DemoTwinData.build({
    required FakeWorkspaceRepository home,
    required FakeFloorPlanRepository productionPlan,
    required FakeWorkspaceRoles productionRoles,
    required String Function() actor,
    required DateTime now,
  }) {
    const ws = demoTwinSpaceId;
    final space = FakeWorkspaceRepository(workspaces: home.workspaces)
      ..myMember = home.myMember.copyWith(workspaceId: ws)
      ..memberNames = {...home.memberNames}
      ..memberEmails = {...home.memberEmails}
      ..otherMembers.addAll([for (final m in home.otherMembers) m.copyWith(workspaceId: ws)]);
    final plan = FakeFloorPlanRepository();
    plan.levels.addAll([for (final l in productionPlan.levels) if (l.workspaceId == 'ws-1') l.copyWith(workspaceId: ws)]);
    plan.offices.addAll([for (final o in productionPlan.offices) if (o.workspaceId == 'ws-1') o.copyWith(workspaceId: ws)]);
    plan.desks.addAll([for (final d in productionPlan.desks) if (d.workspaceId == 'ws-1') d.copyWith(workspaceId: ws)]);
    plan.seats.addAll([for (final s in productionPlan.seats) if (s.workspaceId == 'ws-1') s.copyWith(workspaceId: ws)]);
    plan.levelSites.addAll(productionPlan.levelSites);
    final reservations = RightsCheckedReservationRepository(actor: actor);
    // #3293 — the twin's requests are stamped on the session clock and
    // decided and read only as its own rules and rights allow.
    final events = FakeEventRepository(
      actor: actor,
      workspaceId: ws,
      clock: () => now,
      decider: () => space.memberOf(actor()),
    );
    final money = FakeMoneyRepository(events: events, clock: () => now);
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
    data.roles.roles.addAll(productionRoles.roles);
    for (final e in productionRoles.assignments.entries) {
      data.roles.assignments[e.key] = [...e.value];
    }
    events.viewerPermissions = demoViewerPermissions(space, data.roles, ws, actor);
    // #3305 — each member reads their own statement, as member_statement.
    data.money.accountQueries.statementSource =
        demoStatementSource(data.workspaces, data.reservations, ws, actor: actor, credits: data.credits);
    return data;
  }

  final FakeWorkspaceRepository workspaces;
  final FakeFloorPlanRepository floorPlan;
  final RightsCheckedReservationRepository reservations;
  final FakeEventRepository events;
  final FakeCalendarRepository calendar;
  final FakeMoneyRepository money;

  /// Its own (empty) suppliers, received invoices and purchases.
  final DemoPurchasing purchasing;

  final credits = FakeCreditRepository();
  final accessories = FakeAccessoryRepository();
  final chargingStations = FakeChargingStationRepository();
  final fields = FakeWorkspaceFields();
  final roles = FakeWorkspaceRoles();
  late final planResources = FakePlanResourceRepository(floorPlan);

  /// The twin row while the persona is not a member of the pair.
  Workspace? _parked;

  /// Looks at the twin as [memberId], mirroring the production cast's
  /// viewpoint: a persona with no membership (the kiosk) does not see it.
  void viewAs(String memberId, FakeWorkspaceRepository home) {
    final rows = [workspaces.myMember, ...workspaces.otherMembers];
    final mine = rows.where((m) => m.id == memberId).firstOrNull;
    home.extraMyMemberships.removeWhere((m) => m.workspaceId == demoTwinSpaceId);
    final listed = home.workspaces.indexWhere((w) => w.id == demoTwinSpaceId);
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

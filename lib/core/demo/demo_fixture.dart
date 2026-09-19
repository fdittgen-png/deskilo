// SPDX-License-Identifier: 0BSD
//
// #1373 / #1374 — the space a visitor lands in.
//
// One deterministic set of rooms, people and bookings, built from the
// same in-memory repositories the suite has always driven (ADR 0028).
// Deliberately small here: this is the shape, and #1374 is the full
// cross-domain dataset. What it already settles:
//
//   * **the clock is injected** ([kTestNow]), so a booking "today" never
//     expires out of the demo the way a hard-coded date would;
//   * **the identities are synthetic** — no name, address or e-mail of
//     any real person reaches this file, and none ever may;
//   * **it is a production-looking workspace**, because a visitor should
//     see what the product looks like in use, not a development strip.
import 'data/accessory_repository.dart';
import 'data/auth_repository.dart';
import 'data/calendar_repository.dart';
import 'data/credit_repository.dart';
import 'data/event_repository.dart';
import 'data/fixture_clock.dart';
import 'data/floor_plan_repository.dart';
import 'data/money_repository.dart';
import 'data/profile_repository.dart';
import 'data/deployment_repository.dart';
import 'data/notification_service.dart';
import 'data/realtime_sync.dart';
import 'data/reservation_repository.dart';
import 'data/stores.dart';
import 'data/workspace_fields_repository.dart';
import 'data/workspace_roles_repository.dart';
import 'data/workspace_repository.dart';
import 'demo_dataset.dart';
import 'demo_outward_edges.dart';
import 'demo_persona.dart';

/// Everything one Demo session runs on. Built once per session and
/// thrown away when it ends: a reset is a new [DemoFixture], never a
/// cleanup of the old one.
class DemoFixture {
  DemoFixture._({
    required this.auth,
    required this.workspaces,
    required this.floorPlan,
    required this.reservations,
    required this.events,
    required this.calendar,
    required this.money,
    required this.credits,
    required this.accessories,
    required this.profiles,
    required this.deployments,
    required this.files,
    required this.imports,
    required this.fields,
    required this.roles,
    required this.realtime,
    required this.notifications,
    required this.badge,
    required this.outward,
    required this.seededAt,
  });

  /// Seeds the session. [now] is the instant the demo believes it is,
  /// so "today" is always a working day inside the opening hours.
  factory DemoFixture.build({DateTime? now}) {
    final today = now ?? kTestNow;
    final workspaces = FakeWorkspaceRepository.withWorkspace();
    final floorPlan = FakeFloorPlanRepository();
    seedDemoPlan(floorPlan);
    final reservations = FakeReservationRepository();
    final money = FakeMoneyRepository();
    final events = FakeEventRepository();
    // The cast first: everything below points at it (#1374).
    seedDemoPeople(workspaces);
    seedDemoReservations(reservations, floorPlan, today);
    seedDemoMoney(money, today);
    seedDemoEvents(events, today);
    final problems = validateDemoFixture(
      workspaces: workspaces,
      plan: floorPlan,
      reservations: reservations,
      money: money,
    );
    if (problems.isNotEmpty) {
      // Fails closed, and says what is wrong: a session that points at a
      // member or a seat that does not exist looks fine until a screen
      // opens it (#1373's "missing context fails closed").
      throw StateError('the demo session is not coherent: '
          '${problems.join('; ')}');
    }
    return DemoFixture._(
      auth: FakeAuthRepository(userId: initialDemoPersona.userId),
      workspaces: workspaces,
      floorPlan: floorPlan,
      reservations: reservations,
      events: events,
      calendar: FakeCalendarRepository(),
      money: money,
      credits: FakeCreditRepository(),
      accessories: FakeAccessoryRepository(),
      profiles: demoProfiles(),
      deployments: FakeDeploymentRepository(),
      files: FakeWorkspaceFiles(),
      imports: InMemoryWorkspaceImport(),
      fields: FakeWorkspaceFields(),
      roles: FakeWorkspaceRoles(),
      realtime: FakeRealtimeSync(),
      notifications: FakeNotificationService(),
      badge: FakeAppBadge(),
      outward: DemoOutwardEdges(),
      seededAt: today,
    );
  }

  final FakeAuthRepository auth;
  final FakeWorkspaceRepository workspaces;
  final FakeFloorPlanRepository floorPlan;
  final FakeReservationRepository reservations;
  final FakeEventRepository events;
  final FakeCalendarRepository calendar;
  final FakeMoneyRepository money;
  final FakeCreditRepository credits;
  final FakeAccessoryRepository accessories;
  final FakeProfileRepository profiles;
  final FakeDeploymentRepository deployments;
  final FakeWorkspaceFiles files;
  final InMemoryWorkspaceImport imports;

  /// #1288 — the workspace's own questions, and the answers.
  final FakeWorkspaceFields fields;

  /// #1528 — the roles this space defined itself.
  final FakeWorkspaceRoles roles;
  final FakeRealtimeSync realtime;
  final FakeNotificationService notifications;
  final FakeAppBadge badge;

  /// #1377 — what a demo session TRIED to send outwards, and never did.
  final DemoOutwardEdges outward;

  /// The instant this session believes it is.
  final DateTime seededAt;

  /// Looks at the same space through [persona] (#1376).
  ///
  /// The DATA is untouched: only who the fixture answers `fetchMyMember`
  /// with, and the signed-in user beside it, change. Everything above
  /// reads permissions the way it does in live mode, so a member sees a
  /// member's product because `effectivePermissions` says so and not
  /// because a Demo branch hid anything.
  void becomePersona(DemoPersona persona) {
    seedDemoPeopleAs(workspaces, persona.person);
    // The profile rows stay; the "mine" pointer moves with the persona,
    // so Settings shows that person's own name and contact block
    // instead of the first member's (#1514).
    profiles.myUserId = persona.userId;
    auth.signInAs(persona.userId);
  }
}

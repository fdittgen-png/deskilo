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
import 'data/reservation_repository.dart';
import 'data/stores.dart';
import 'data/workspace_repository.dart';

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
    required this.seededAt,
  });

  /// Seeds the session. [now] is the instant the demo believes it is,
  /// so "today" is always a working day inside the opening hours.
  factory DemoFixture.build({DateTime? now}) {
    final today = now ?? kTestNow;
    final workspaces = FakeWorkspaceRepository.withWorkspace();
    final floorPlan = FakeFloorPlanRepository()..seedSmallPlan();
    final reservations = FakeReservationRepository();
    return DemoFixture._(
      auth: FakeAuthRepository.signedIn(),
      workspaces: workspaces,
      floorPlan: floorPlan,
      reservations: reservations,
      events: FakeEventRepository(),
      calendar: FakeCalendarRepository(),
      money: FakeMoneyRepository(),
      credits: FakeCreditRepository(),
      accessories: FakeAccessoryRepository(),
      profiles: FakeProfileRepository(),
      deployments: FakeDeploymentRepository(),
      files: FakeWorkspaceFiles(),
      imports: InMemoryWorkspaceImport(),
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

  /// The instant this session believes it is.
  final DateTime seededAt;
}

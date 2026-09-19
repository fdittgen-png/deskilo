// SPDX-License-Identifier: 0BSD
//
// #1373 — what makes a `ProviderScope` the Demo environment.
//
// ADR 0028: Demo is the repository seam, with no backend behind it. This
// is that seam as a list — every provider that would otherwise resolve
// to a Supabase-backed implementation, overridden with the in-memory one
// the fixture seeded.
//
// The guarantee is structural, not a promise: inside a scope built from
// these overrides there is no Supabase client to reach, so an invitation,
// a payment, an e-invoice or a push cannot leave. There is no `if (demo)`
// branch to forget, because there is no code path at all.
//
// Everything a member could change in Demo lives in the fixture, so
// leaving the scope disposes it and a reset is a new fixture rather than
// a cleanup of the old one (#1375).
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../features/auth/providers/auth_providers.dart';
import '../../features/events/providers/event_providers.dart';
import '../../features/money/providers/credit_providers.dart';
import '../../features/money/providers/money_providers.dart';
import '../../features/plan/providers/accessory_providers.dart';
import '../../features/plan/providers/floor_plan_providers.dart';
import '../../features/profile/providers/profile_providers.dart';
import '../../features/reservations/providers/reservation_providers.dart';
import '../../features/calendar/providers/calendar_providers.dart';
import '../../features/workspace/providers/deployment_providers.dart';
import '../../features/workspace/providers/workspace_files_providers.dart';
import '../../features/workspace/providers/workspace_import_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../time/clock.dart';
import 'demo_fixture.dart';

/// The overrides that turn a scope into the Demo environment.
///
/// [fixture] is the session's data; a new one is a new session.
List<Override> demoOverrides(DemoFixture fixture) => [
      // The clock first: everything the fixture seeded is relative to it,
      // so a demo opened next year still shows a booking for today.
      clockProvider.overrideWithValue(FixedClock(fixture.seededAt)),

      // The repositories. Each of these would otherwise be constructed
      // from `Supabase.instance.client`; inside this scope none of them
      // is, which is what makes an external effect impossible rather
      // than refused.
      authRepositoryProvider.overrideWithValue(fixture.auth),
      workspaceRepositoryProvider.overrideWithValue(fixture.workspaces),
      floorPlanRepositoryProvider.overrideWithValue(fixture.floorPlan),
      reservationRepositoryProvider.overrideWithValue(fixture.reservations),
      eventRepositoryProvider.overrideWithValue(fixture.events),
      calendarRepositoryProvider.overrideWithValue(fixture.calendar),
      moneyRepositoryProvider.overrideWithValue(fixture.money),
      creditRepositoryProvider.overrideWithValue(fixture.credits),
      accessoryRepositoryProvider.overrideWithValue(fixture.accessories),
      profileRepositoryProvider.overrideWithValue(fixture.profiles),
      deploymentRepositoryProvider.overrideWithValue(fixture.deployments),
      workspaceFilesRepositoryProvider.overrideWithValue(fixture.files),
      workspaceImportRepositoryProvider.overrideWithValue(fixture.imports),
    ];

/// The providers a Demo scope must override, by name.
///
/// The list exists so a NEW repository cannot quietly stay live in Demo:
/// `demo_scope_test` compares it against what [demoOverrides] actually
/// overrides, and against the repository providers the app declares.
const Set<String> demoOverriddenProviders = {
  'clockProvider',
  'authRepositoryProvider',
  'workspaceRepositoryProvider',
  'floorPlanRepositoryProvider',
  'reservationRepositoryProvider',
  'eventRepositoryProvider',
  'calendarRepositoryProvider',
  'moneyRepositoryProvider',
  'creditRepositoryProvider',
  'accessoryRepositoryProvider',
  'profileRepositoryProvider',
  'deploymentRepositoryProvider',
  'workspaceFilesRepositoryProvider',
  'workspaceImportRepositoryProvider',
};

// SPDX-License-Identifier: 0BSD
//
// #1378 — the harness a Demo journey runs on.
//
// A journey test drives the REAL screens against the REAL demo fixture.
// Nothing here is a stand-in for the product: the repositories are the
// ones `demoOverrides` installs when a visitor enters the demonstration
// space, so a journey that passes here is a journey a visitor can walk.
//
// What it does NOT do is boot the app the way `main()` does. The device
// preferences — the active workspace, the default period, the help
// hints — come from `standardTestOverrides` in memory, because a test
// that waited on real preference storage would be waiting on the boot
// splash's six-second timer rather than on the product.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'mock_providers.dart';

/// One demonstration session, and the overrides that put the app on it.
class DemoJourney {
  DemoJourney._(this.fixture, this.overrides);

  /// Starts a session at the canonical baseline, as a visitor's first
  /// moment in the space. [persona] is who they are looking through.
  factory DemoJourney.start({DemoPersona persona = initialDemoPersona}) {
    final fixture = DemoFixture.build();
    fixture.becomePersona(persona);
    return DemoJourney._(
      fixture,
      standardTestOverrides(
        // The demo's own clock: everything the fixture seeded is
        // relative to it, so "today" is the day the dataset means.
        clock: FixedClock(fixture.seededAt),
        auth: fixture.auth,
        workspace: fixture.workspaces,
        floorPlan: fixture.floorPlan,
        reservations: fixture.reservations,
        events: fixture.events,
        calendar: fixture.calendar,
        money: fixture.money,
        credits: fixture.credits,
        accessories: fixture.accessories,
        deployment: fixture.deployments,
        workspaceFiles: fixture.files,
        notifications: fixture.notifications,
        realtime: fixture.realtime,
        badge: fixture.badge,
      ),
    );
  }

  /// The session's data, to assert against after the journey.
  final DemoFixture fixture;

  /// What to give a `ProviderScope`.
  final List<Override> overrides;
}

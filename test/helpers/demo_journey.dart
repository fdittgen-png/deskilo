// SPDX-License-Identifier: 0BSD
//
// #1378 — the harness a Demo journey runs on.
//
// A journey test drives the REAL screens against the REAL demo fixture,
// through the REAL composition: `DeskiloRoot` with `demoEntry` entered,
// which mounts `DemoWorkspace`, which builds its own root container from
// `demoOverrides`. Nothing here stands in for the product.
//
// It used to assemble `standardTestOverrides` from the fixture's
// repositories instead, and that hid #1564 completely: the suite's
// baseline overrides the preference stores, the schema source and the
// backend settings in memory, so every leak Demo had into the real
// device was patched over by the harness and by nothing in the product.
// It also put the persona out of reach — the demonstration bar only
// renders under a `DemoEnvironment`, so the journeys set the fake actor
// by hand and never drove the control a visitor uses, which is how
// #1565 stayed invisible.
//
// The session controller lives in the OUTER container, so a test can
// read the fixture and reach the same object the screens are writing to.
import 'package:deskilo/core/demo/demo_entry.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One demonstration session, and the container the app runs in.
class DemoJourney {
  DemoJourney._(this.root);

  /// Starts a session at the canonical baseline, as a visitor's first
  /// moment in the space. [persona] is who they are looking through.
  factory DemoJourney.start({DemoPersona persona = initialDemoPersona}) {
    final root = ProviderContainer();
    root.read(demoEntryProvider.notifier).enter();
    root.read(demoSessionControllerProvider.notifier).viewAs(persona);
    return DemoJourney._(root);
  }

  /// The container `DeskiloRoot` is mounted in. It holds the session and
  /// the demo-entry flag; everything else is hosted in the Demo
  /// container `DemoWorkspace` builds under it.
  final ProviderContainer root;

  DemoSession get session => root.read(demoSessionControllerProvider);

  /// The session's data, to assert against after the journey.
  DemoFixture get fixture => session.fixture;

  /// Who the visitor is looking through right now.
  DemoPersona get persona => session.persona;

  void dispose() => root.dispose();
}

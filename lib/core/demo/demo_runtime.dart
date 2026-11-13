// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3848 — the Demo's deferred library: everything that needs its fixture.
//
// On the web this file and what it reaches (the session, the fixture, the
// scope's overrides, the repositories and the seed data) are fetched when
// the Demo is entered, not with the app's first download. It is imported
// only by `demo_loader.dart`, `deferred as runtime`; `demo_loader_test.dart`
// in test/lint keeps every other file outside this folder from importing
// what it reaches.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo_persona.dart';
import 'demo_session.dart';
import 'presentation/demo_workspace.dart';

/// The Demo environment around [child].
Widget buildDemoWorkspace(Widget child) => DemoWorkspace(child: child);

/// Builds the session's fixture, looking through [persona] when one is
/// named (#2872), before anything is committed.
void startDemoSession(WidgetRef ref, DemoPersona? persona) {
  ref.read(demoSessionControllerProvider);
  if (persona != null) {
    ref.read(demoSessionControllerProvider.notifier).viewAs(persona);
  }
}

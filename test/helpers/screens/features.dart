// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1864 C — the Features screen pump, moved out of `test/features/workspace/features_screen_test.dart`:
// the accessibility matrix, the locale walk and the other suites that
// reuse it import this helper instead of a whole test file.
import 'package:deskilo/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../mock_providers.dart';
import '../settings_sections.dart';

Future<FakeWorkspaceRepository> pumpSettings(
  WidgetTester tester, {
  Map<String, dynamic> featureFlags = const {},
}) async {
  final workspace =
      FakeWorkspaceRepository.withWorkspace(featureFlags: featureFlags);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  await showWorkspaceSettings(tester);
  return workspace;
}

Future<FakeWorkspaceRepository> pumpFeatures(
  WidgetTester tester, {
  Map<String, dynamic> featureFlags = const {},
  // #1339 — the responsive matrix asks for a narrow surface. Every
  // other caller keeps the tall one this file has always used, so
  // nothing existing changes.
  // 2026-09-16 — 103 manifest features (#1274) outgrow 17000 px, and a
  // lazy list simply stops building the tail.
  // 2026-09-25 — 114 manifest features (#1654) outgrow 18000 px.
  // 2026-10-01 — #1850 gave every tile a maturity line; 20000 px dropped
  // the tail.
  Size size = const Size(800, 24000),
  // #1327 — the screen opens on the process overview. Every caller of
  // this helper pins the switches, so it opens that view unless asked
  // not to.
  bool switches = true,
}) async {
  // Ten manifest features no longer fit the default 800×600 surface and
  // the lazy list drops off-screen tiles; keep every switch mounted.
  // #759 lengthened four descriptions, so the list outgrew 5600 px.
  // #800 gave every tile a second note line, and #802 added two more
  // features — 7200 px stopped fitting the last two switches. #821–#831
  // added five more with long descriptions; 9600 px dropped the last.
  // 2026-09-05 — 82 manifest features (#874) outgrow 12000 px.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final workspace =
      await pumpSettings(tester, featureFlags: featureFlags);
  // #1246 — by icon, not by the English label.
  // #1339 — and bring it on stage first. The tile is far down a lazy
  // list, so on a short viewport it is simply not built and the tap
  // finds nothing. Tall viewports hid that for as long as this helper
  // has existed.
  await tester.scrollUntilVisible(find.byIcon(Icons.toggle_on_outlined), 200);
  await tester.ensureVisible(find.byIcon(Icons.toggle_on_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.toggle_on_outlined));
  await tester.pumpAndSettle();
  if (switches) {
    await tester.tap(find.byKey(const ValueKey('features-view-switches')));
    await tester.pumpAndSettle();
  }
  return workspace;
}

SwitchListTile switchTitled(WidgetTester tester, String title) =>
    tester.widget<SwitchListTile>(
      find.ancestor(
        of: find.text(title),
        matching: find.byType(SwitchListTile),
      ),
    );

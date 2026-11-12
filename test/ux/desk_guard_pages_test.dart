// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3605 (desk F4) — the desk guards on their first pages, through the app's
// builder at 1024, 1440 and 1920: /invoices, a records page, and the Me
// overview. With SHEET=1 each writes its sheet at 390 and 1440, light and
// dark, to build/sheets/<module>/ (docs/testing/desk-guards.md).
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/ui/kit/table_line.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';
import 'experience_guards.dart';

Future<void> _open(WidgetTester tester, String path, Size size) async {
  final features = WorkspaceFeature.values.toSet();
  final app = ProviderScope(
    overrides: [
      ...standardTestOverrides(
        workspace: FakeWorkspaceRepository.withWorkspace(
          featureFlags: {for (final f in features) f.name: true},
        ),
      ),
      enabledFeaturesSyncProvider.overrideWithValue(features),
    ],
    child: const DeskiloApp(),
  );
  await pumpRoute(
    tester,
    app,
    path,
    size: size,
    go: (p) =>
        ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)))
            .read(routerProvider)
            .go(p),
  );
}

/// The pages the guards run on: path, kind, module and screen for a sheet.
const _pages = [
  ('/invoices', PageKind.records, 'money', 'invoices'),
  ('/me', PageKind.dashboard, 'me', 'overview'),
];

void main() {
  setUpAll(loadSheetFonts);

  for (final (path, kind, module, screen) in _pages) {
    for (final size in deskGuardSizes) {
      testWidgets('$path at ${size.width.toInt()}: the desk guards hold', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await _open(tester, path, size);
        expect(
          deskGuardProblems(
            tester,
            kind: kind,
            size: size,
            rowTypes: const [KitTableLine],
            tableTypes: const [KitTableHeader],
          ),
          isEmpty,
        );
        expect(await keyboardProblems(tester), isEmpty);
        semantics.dispose();
      });
    }
    for (final width in [390.0, 1440.0]) {
      for (final brightness in Brightness.values) {
        testWidgets('$path sheet at ${width.toInt()}, ${brightness.name}', (
          tester,
        ) async {
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          await _open(tester, path, Size(width, 900));
          await writeDeskSheet(
            tester,
            module: module,
            screen: screen,
            width: width,
            brightness: brightness,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

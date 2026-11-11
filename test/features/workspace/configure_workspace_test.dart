// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3282 — one "Configure workspace" door, in the menu and at the top of
// Settings' "Manage workspace": the guide for whoever may configure (the
// permission its routes ask), else the deepest page the reader may open.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/configure_workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/settings_sections.dart';

const _places = {WorkspaceFeature.placeBooking};

String? _route(Set<WorkspacePermission> p, {bool open = true}) =>
    configureWorkspaceRoute(permissions: p, features: _places, setupOpen: open);

void main() {
  test('the owner goes to the guide; a delegate to the page they may open', () {
    expect(_route(WorkspacePermission.values.toSet()), '/setup');
    expect(
      _route({WorkspacePermission.workspaceSettings}),
      '/workspace-settings',
      reason: 'the guide asks manageConfiguration: never a door that refuses',
    );
    expect(
      _route({WorkspacePermission.manageConfiguration}, open: false),
      '/features',
    );
    expect(_route({WorkspacePermission.manageSites}), '/editor');
    expect(
      configureWorkspaceRoute(
        permissions: {WorkspacePermission.manageSites},
        features: const {},
        setupOpen: true,
      ),
      isNull,
      reason: 'no places, no plan to edit',
    );
    expect(_route(const {}), isNull);
  });

  testWidgets('"Manage workspace" opens with the Configure workspace door', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await showWorkspaceSettings(tester);
    final tile = find.byKey(const ValueKey('settings-configure-workspace'));
    expect(tile, findsOneWidget);
    expect(
      find.descendant(of: tile, matching: find.text('Configure workspace')),
      findsOneWidget,
    );
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(tile, findsNothing, reason: 'the door opened its page');
    expect(tester.takeException(), isNull);
  });
}

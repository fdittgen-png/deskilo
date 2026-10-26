// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The app bar's space chip fits whatever title box the bar leaves it: on a
// 360 px screen with twice the text and the web shell's drawer button and
// actions beside it, the chip drops the space's avatar and ellipsizes the
// name, so nothing overflows; on a roomy bar the ring stays.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

/// The current space; with [branded] it wears a colour and a pattern, so
/// the chip has its ring.
FakeWorkspaceRepository _space({required bool branded}) {
  final repo = FakeWorkspaceRepository.withWorkspace(
    featureFlags: {'workspaceBranding': branded},
  );
  if (branded) {
    repo.workspaces[0] = repo.workspaces[0].copyWith(
      branding: const {'seed_color': '#0F766E', 'pattern': 'stripes'},
    );
  }
  return repo;
}

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required double textScale,
  required bool branded,
}) async {
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  tester.view.physicalSize = Size(width, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(workspace: _space(branded: branded)),
        webShellProvider.overrideWithValue(true),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _ring => find.byKey(const ValueKey('space-chip-brand'));
Finder get _name => find.byKey(const ValueKey('space-chip-name'));

void main() {
  for (final branded in [false, true]) {
    testWidgets('on a 360 px screen with twice the text the chip fits '
        '(${branded ? 'a branded space' : 'a plain space'}): the avatar is '
        'dropped, the name ellipsizes, nothing overflows', (tester) async {
      await _pump(tester, width: 360, textScale: 2, branded: branded);
      expect(tester.takeException(), isNull, reason: 'nothing overflows');
      expect(_name, findsOneWidget);
      expect(_ring, findsNothing);
    });
  }

  testWidgets('on a roomy bar the space keeps its ring', (tester) async {
    await _pump(tester, width: 1024, textScale: 1, branded: true);
    expect(tester.takeException(), isNull);
    expect(_ring, findsOneWidget);
    expect(_name, findsOneWidget);
  });
}

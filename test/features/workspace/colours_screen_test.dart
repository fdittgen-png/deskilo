// SPDX-License-Identifier: 0BSD
//
// #1289 S2 — the screen where a space chooses its colour.
import 'package:deskilo/features/workspace/presentation/screens/colours_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<FakeWorkspaceRepository> _pump(
  WidgetTester tester, {
  Map<String, dynamic> branding = const {},
  Size size = const Size(800, 1400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final workspace = FakeWorkspaceRepository.withWorkspace(
    featureFlags: const {'workspaceBranding': true},
  );
  workspace.workspaces[0] =
      workspace.workspaces[0].copyWith(branding: branding);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ColoursScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return workspace;
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const ValueKey('colours-hex')), text);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a suggested colour fills the field and saving stores it '
      'upper-case', (tester) async {
    final workspace = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('colours-pick-#1F3A5F')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('colours-apply')));
    await tester.pumpAndSettle();

    expect(workspace.brandings['ws-1'], {'seed_color': '#1F3A5F'});
  });

  testWidgets('a typed colour is stored; the preview is there to see it '
      'first', (tester) async {
    final workspace = await _pump(tester);
    expect(find.byKey(const ValueKey('colours-preview')), findsOneWidget);
    await _type(tester, '#00695c');
    await tester.tap(find.byKey(const ValueKey('colours-apply')));
    await tester.pumpAndSettle();

    expect(workspace.brandings['ws-1'], {'seed_color': '#00695C'});
  });

  testWidgets('the reset removes the colour rather than storing the '
      "product's", (tester) async {
    final workspace = await _pump(tester, branding: {'seed_color': '#1F3A5F'});
    await tester.tap(find.byKey(const ValueKey('colours-reset')));
    await tester.pumpAndSettle();

    expect(workspace.brandings['ws-1'], isEmpty,
        reason: 'the key is removed, not written back as the default');
  });

  testWidgets('nothing chosen: there is nothing to reset', (tester) async {
    await _pump(tester);
    final reset = tester.widget<TextButton>(
        find.byKey(const ValueKey('colours-reset')));
    expect(reset.onPressed, isNull);
  });

  testWidgets('what a workspace may never restyle is written on the screen',
      (tester) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('colours-never')), findsOneWidget);
  });

  testWidgets('room colours: the product palette shows until the space '
      'adds one of its own, and the order is what is stored',
      (tester) async {
    final workspace = await _pump(tester);
    expect(find.byKey(const ValueKey('colours-room-0')), findsOneWidget);
    expect(find.text('The product palette. Add a colour to use your own.'),
        findsOneWidget);

    for (final hex in ['#EBDCC9', '#CFE3DC']) {
      await tester.enterText(
          find.byKey(const ValueKey('colours-room-hex')), hex);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('colours-room-add')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('colours-rooms-save')));
    await tester.pumpAndSettle();

    expect(workspace.brandings['ws-1'],
        {'office_palette': ['#EBDCC9', '#CFE3DC']});
  });

  testWidgets('room colours: the reset removes the list, not the seed',
      (tester) async {
    final workspace = await _pump(tester, branding: {
      'seed_color': '#1F3A5F',
      'office_palette': ['#EBDCC9'],
    });
    await tester.tap(find.byKey(const ValueKey('colours-rooms-reset')));
    await tester.pumpAndSettle();

    expect(workspace.brandings['ws-1'], {'seed_color': '#1F3A5F'},
        reason: 'the fills go, the brand colour stays');
  });

  testWidgets('360 dp: no overflow', (tester) async {
    await _pump(tester, size: const Size(360, 1600));
    expect(tester.takeException(), isNull);
  });
}

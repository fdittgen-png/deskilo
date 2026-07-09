// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<FakeWorkspaceRepository> pumpWorkspaceSettings(
  WidgetTester tester,
) async {
  final workspace = FakeWorkspaceRepository.withWorkspace();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Workspace'));
  await tester.pumpAndSettle();
  return workspace;
}

void main() {
  testWidgets(
      'workspace settings seed from the current workspace and save the '
      'edited locale through the repository (#153)', (tester) async {
    final workspace = await pumpWorkspaceSettings(tester);

    // Seeded from ws-1 (DE / EUR / Europe/Berlin).
    expect(find.text('Test Space'), findsOneWidget);
    expect(find.text('EUR'), findsOneWidget);
    expect(find.text('Europe/Berlin'), findsOneWidget);

    // Picking Switzerland re-defaults currency + time zone (spec §3).
    await tester.tap(find.byKey(const Key('workspaceSettingsCountry')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Switzerland').last);
    await tester.pumpAndSettle();
    expect(find.text('CHF'), findsOneWidget);
    expect(find.text('Europe/Zurich'), findsOneWidget);

    await tester.tap(find.byKey(const Key('workspaceSettingsSave')));
    await tester.pumpAndSettle();

    expect(workspace.lastLocaleUpdate,
        ['ws-1', 'CH', 'CHF', 'Europe/Zurich']);
    expect(find.text('Workspace saved.'), findsOneWidget);
  });

  testWidgets(
      'a manual currency override typed after the country pick is saved '
      'verbatim (owner-overridable, spec §3)', (tester) async {
    final workspace = await pumpWorkspaceSettings(tester);

    await tester.tap(find.byKey(const Key('workspaceSettingsCountry')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Switzerland').last);
    await tester.pumpAndSettle();

    // Owner overrides the CHF default with EUR before saving.
    await tester.enterText(
        find.byKey(const Key('workspaceSettingsCurrency')), 'eur');
    await tester.tap(find.byKey(const Key('workspaceSettingsSave')));
    await tester.pumpAndSettle();

    expect(workspace.lastLocaleUpdate,
        ['ws-1', 'CH', 'EUR', 'Europe/Zurich']);
  });

  testWidgets('an invalid currency code blocks the save', (tester) async {
    final workspace = await pumpWorkspaceSettings(tester);

    await tester.enterText(
        find.byKey(const Key('workspaceSettingsCurrency')), 'EU');
    await tester.tap(find.byKey(const Key('workspaceSettingsSave')));
    await tester.pumpAndSettle();

    expect(workspace.lastLocaleUpdate, isNull);
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('non-owners see no Workspace entry in settings',
      (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.myMember =
        workspace.myMember.copyWith(isOwner: false, isAdmin: false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(workspace: workspace),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Workspace'), findsNothing);
  });
}

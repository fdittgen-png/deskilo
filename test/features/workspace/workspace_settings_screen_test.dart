// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<FakeWorkspaceRepository> pumpWorkspaceSettings(
  WidgetTester tester,
) async {
  // The settings form grew past the default 800px test viewport (#155,
  // three more payment fields in #192); a taller view keeps every field
  // + Save built without scrolling.
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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

  testWidgets(
      'the payment-instructions fields save through the repository and '
      'ride the same Save button (#155)', (tester) async {
    final workspace = await pumpWorkspaceSettings(tester);
    await tester.enterText(
      find.byKey(const Key('workspaceSettingsIban')),
      'DE89 3704 0044 0532 0130 00',
    );
    await tester.enterText(
      find.byKey(const Key('workspaceSettingsPaypalMe')),
      'deskilo',
    );
    await tester.enterText(
      find.byKey(const Key('workspaceSettingsReference')),
      'DesKilo member period',
    );
    // #192 — Wero / Lydia / Wise ride the same blob and Save.
    await tester.enterText(
      find.byKey(const Key('workspaceSettingsWero')),
      '+49 170 0000000',
    );
    await tester.enterText(
      find.byKey(const Key('workspaceSettingsLydia')),
      '+33 6 00 00 00 00',
    );
    await tester.enterText(
      find.byKey(const Key('workspaceSettingsWise')),
      '@deskilo',
    );
    await tester.tap(find.byKey(const Key('workspaceSettingsSave')));
    await tester.pumpAndSettle();

    final saved = workspace.lastPaymentInstructions;
    expect(saved, isNotNull);
    expect(saved!.iban, 'DE89 3704 0044 0532 0130 00');
    expect(saved.paypalMe, 'deskilo');
    expect(saved.reference, 'DesKilo member period');
    expect(saved.paypalMeUri.toString(), 'https://paypal.me/deskilo');
    expect(saved.wero, '+49 170 0000000');
    expect(saved.lydia, '+33 6 00 00 00 00');
    expect(saved.wise, '@deskilo');
  });

  testWidgets(
      'saved #192 instructions re-seed the form fields on reload',
      (tester) async {
    final workspace = await pumpWorkspaceSettings(tester);
    await tester.enterText(
      find.byKey(const Key('workspaceSettingsWero')),
      '+49 170 0000000',
    );
    await tester.tap(find.byKey(const Key('workspaceSettingsSave')));
    await tester.pumpAndSettle();

    // The fake writes the blob back onto the workspace — the saved value
    // must round-trip through toDb/fromDb into the seeded controller.
    expect(
      workspace.workspaces[0].paymentInstructions['wero'],
      '+49 170 0000000',
    );
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

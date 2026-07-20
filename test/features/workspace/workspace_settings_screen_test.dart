// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/share/share_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';

Future<FakeWorkspaceRepository> pumpWorkspaceSettings(
  WidgetTester tester, {
  ShareLauncher? share,
  FakeFloorPlanRepository? floorPlan,
}) async {
  // The settings form grew past the default 800px test viewport (#155,
  // three more payment fields in #192, the WhatsApp-group section in
  // #231); a taller view keeps every field + Save built without
  // scrolling.
  tester.view.physicalSize = const Size(800, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final workspace = FakeWorkspaceRepository.withWorkspace();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(workspace: workspace, floorPlan: floorPlan),
        if (share != null) shareLauncherProvider.overrideWithValue(share),
      ],
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

  testWidgets(
      'a valid WhatsApp group link rides the same Save through the '
      'repository (#231)', (tester) async {
    final workspace = await pumpWorkspaceSettings(tester);
    await tester.enterText(
      find.byKey(const Key('workspaceSettingsWhatsappGroup')),
      'https://chat.whatsapp.com/AbCdEf123456',
    );
    await tester.tap(find.byKey(const Key('workspaceSettingsSave')));
    await tester.pumpAndSettle();

    expect(
      workspace.lastWhatsappGroup,
      'https://chat.whatsapp.com/AbCdEf123456',
    );
    // The fake writes it back onto the workspace — the saved link
    // re-seeds the field on reload.
    expect(
      workspace.workspaces[0].whatsappGroup,
      'https://chat.whatsapp.com/AbCdEf123456',
    );
    expect(find.text('Workspace saved.'), findsOneWidget);
  });

  testWidgets(
      'a non-chat.whatsapp.com link is rejected client-side and blocks '
      'the whole save (#231)', (tester) async {
    final workspace = await pumpWorkspaceSettings(tester);
    await tester.enterText(
      find.byKey(const Key('workspaceSettingsWhatsappGroup')),
      'https://example.com/not-a-group',
    );
    await tester.tap(find.byKey(const Key('workspaceSettingsSave')));
    await tester.pumpAndSettle();

    // The form validator (same prefix rule as the 0029 check) blocked
    // the save — nothing was written.
    expect(workspace.lastWhatsappGroup, isNull);
    expect(workspace.lastLocaleUpdate, isNull);
    expect(
      find.text('Must be a chat.whatsapp.com invite link'),
      findsOneWidget,
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

  testWidgets(
      'the owner exports the configuration as a PDF through the share seam',
      (tester) async {
    final captured = <ShareParams>[];
    final floorPlan = FakeFloorPlanRepository()..seedSmallPlan();
    await pumpWorkspaceSettings(
      tester,
      floorPlan: floorPlan,
      share: (params) async => captured.add(params),
    );

    final button = find.byKey(const Key('workspaceSettingsExportPdf'));
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(captured, hasLength(1));
    expect(
      captured.single.fileNameOverrides,
      ['Test Space-configuration.pdf'],
    );
    final file = captured.single.files!.single;
    expect(file.mimeType, 'application/pdf');
  });

  testWidgets(
      'reset workspace is gated on typing the confirm phrase, then calls the '
      'repository', (tester) async {
    final workspace = await pumpWorkspaceSettings(tester);

    // Open the destructive dialog from the Danger zone.
    final resetTile = find.byKey(const Key('workspaceSettingsReset'));
    await tester.ensureVisible(resetTile);
    await tester.tap(resetTile);
    await tester.pumpAndSettle();

    // The confirm button is disabled until the exact phrase is typed.
    FilledButton confirmButton() => tester.widget<FilledButton>(
          find.byKey(const Key('workspaceResetConfirm')),
        );
    expect(confirmButton().onPressed, isNull);
    expect(workspace.resetWorkspaceCalls, isEmpty);

    // A wrong phrase keeps it disabled.
    await tester.enterText(
      find.byKey(const Key('workspaceResetConfirmField')),
      'yes',
    );
    await tester.pump();
    expect(confirmButton().onPressed, isNull);

    // The exact phrase (case-insensitive) unlocks it.
    await tester.enterText(
      find.byKey(const Key('workspaceResetConfirmField')),
      'I AGREE',
    );
    await tester.pump();
    expect(confirmButton().onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('workspaceResetConfirm')));
    await tester.pumpAndSettle();

    expect(workspace.resetWorkspaceCalls, ['ws-1']);
    expect(find.text('Workspace reset.'), findsOneWidget);
  });

  testWidgets('cancelling the reset dialog does nothing', (tester) async {
    final workspace = await pumpWorkspaceSettings(tester);
    final resetTile = find.byKey(const Key('workspaceSettingsReset'));
    await tester.ensureVisible(resetTile);
    await tester.tap(resetTile);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(workspace.resetWorkspaceCalls, isEmpty);
  });
}

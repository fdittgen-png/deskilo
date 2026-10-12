// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2459 — the sign-in form offers the welcome page beside the demo.
import 'package:deskilo/core/demo/presentation/demo_entry_sheet.dart';
import 'package:deskilo/core/demo/presentation/welcome_link_button.dart';
import 'package:deskilo/core/links/link_launcher.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [DemoEntryButton(), WelcomeLinkButton()],
            ),
          ),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the link is the welcome page, opened at its top', () {
    expect(WelcomeLinkButton.url.toString(), 'https://deskilo.org/welcome/#top');
  });

  testWidgets('the demo and the welcome link show, and the link opens exactly that page', (
    tester,
  ) async {
    final opened = <Uri>[];
    final container = ProviderContainer(
      overrides: [
        linkLauncherProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));

    expect(find.byKey(DemoEntryButton.buttonKey), findsOneWidget);
    expect(find.byKey(WelcomeLinkButton.buttonKey), findsOneWidget);
    expect(find.text('What is DesKilo?'), findsOneWidget);

    await tester.tap(find.byKey(WelcomeLinkButton.buttonKey));
    await tester.pump();
    expect(opened, [WelcomeLinkButton.url]);
  });

  testWidgets('with the demo flag off neither offer is shown', (tester) async {
    final container = ProviderContainer(
      overrides: [
        enabledFeaturesSyncProvider.overrideWithValue({
          for (final f in WorkspaceFeature.values)
            if (f != WorkspaceFeature.demoMode) f,
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));

    expect(find.byKey(DemoEntryButton.buttonKey), findsNothing);
    expect(find.byKey(WelcomeLinkButton.buttonKey), findsNothing);
  });
}

// SPDX-License-Identifier: AGPL-3.0-or-later
// #1653: Back edits steps; leaving a populated draft requires actual discard.
import 'package:deskilo/features/workspace/presentation/screens/onboarding_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/mock_providers.dart';

void main() {
  testWidgets('system Back edits; Escape and visible Back preserve or discard explicitly', (tester) async {
    final repo = FakeWorkspaceRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: standardTestOverrides(workspace: repo),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) => Scaffold(body: TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const OnboardingScreen())), child: const Text('Open')))),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final name = find.byKey(const ValueKey('onboarding-name'));
    await tester.enterText(name, 'Draft to keep');
    await tester.tap(find.byKey(const ValueKey('wizard-next')));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<TextFormField>(name).controller!.text, 'Draft to keep');
    expect(find.byType(AlertDialog), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('wizard-keep-draft')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<TextFormField>(name).controller!.text, 'Draft to keep');
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('wizard-discard-draft')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Open'), findsOneWidget);
    expect(repo.createRequests, isEmpty);
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

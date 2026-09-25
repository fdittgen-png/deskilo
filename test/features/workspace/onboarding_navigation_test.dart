// SPDX-License-Identifier: AGPL-3.0-or-later
// #1653: Back edits steps; leaving a populated draft requires actual discard.
import 'package:deskilo/features/workspace/presentation/screens/onboarding_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'dart:async';
import 'package:deskilo/core/ui/wizard_navigation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/mock_providers.dart';

void main() {
  testWidgets('disposing an older frame preserves the active guard', (tester) async {
    final controller = WizardNavigationController();
    Widget frame(String key) => WizardNavigation(key: ValueKey(key), controller: controller,
      busy: true, hasDraft: false, discardMessage: '', builder: (_) => const SizedBox());
    await tester.pumpWidget(MaterialApp(home: Column(children: [frame('old'), frame('active')])));
    await tester.pumpWidget(MaterialApp(home: Column(children: [frame('active')])));
    expect(await controller.requestExit(), isFalse);
  });

  testWidgets('browser route changes use the same step and discard guard', (tester) async {
    final navigation = WizardNavigationController();
    final router = GoRouter(initialLocation: '/onboarding', routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox()),
      GoRoute(path: '/onboarding', onExit: (_, _) => navigation.requestExit(),
        builder: (_, _) => OnboardingScreen(navigation: navigation)),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: standardTestOverrides(),
      child: MaterialApp.router(routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales)));
    await tester.pump();
    final name = find.byKey(const ValueKey('onboarding-name'));
    await tester.enterText(name, 'Browser draft');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('wizard-next')));
    await tester.pump();
    await router.routeInformationProvider.didPushRouteInformation(RouteInformation(uri: Uri.parse('/')));
    await tester.pump();
    expect(tester.widget<TextFormField>(name).controller!.text, 'Browser draft');
    unawaited(router.routeInformationProvider.didPushRouteInformation(RouteInformation(uri: Uri.parse('/'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wizard-discard-draft')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/');
    expect(find.byType(OnboardingScreen), findsNothing);
  });

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

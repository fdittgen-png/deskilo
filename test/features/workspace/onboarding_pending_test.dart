// SPDX-License-Identifier: AGPL-3.0-or-later
// #1653: one creation stays visible while pending; timeout/disposal never cancel it.
import 'dart:async';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/presentation/screens/onboarding_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/mock_providers.dart';

class HeldCreation extends FakeWorkspaceRepository {
  Completer<void> gate = Completer<void>();
  final requests = <String?>[];
  @override
  Future<String> createWorkspace({required String name, required String countryCode,
    required String currencyCode, required String timezone,
    WorkspaceEnvironment environment = WorkspaceEnvironment.development,
    bool withTwin = true, String? requestId, String? templateId}) async {
    requests.add(requestId);
    await gate.future;
    return super.createWorkspace(name: name, countryCode: countryCode,
      currencyCode: currencyCode, timezone: timezone, environment: environment,
      withTwin: withTwin, requestId: requestId, templateId: templateId);
  }
}

Future<void> ready(WidgetTester tester, HeldCreation repo) async {
  final router = GoRouter(routes: [GoRoute(path: '/',
    builder: (_, _) => const OnboardingScreen())]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: standardTestOverrides(workspace: repo),
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router),
  ));
  await tester.pump();
  await tester.enterText(find.byKey(const ValueKey('onboarding-name')), 'Kept draft');
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('onboarding-use-suggested')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('double submit and back while pending keep one labelled request', (tester) async {
    final repo = HeldCreation();
    await ready(tester, repo);
    final create = find.byKey(const ValueKey('onboarding-create'));
    final size = tester.getSize(create);
    final action = tester.widget<FilledButton>(create).onPressed!;
    action(); action();
    await tester.pump();
    expect(repo.requests, hasLength(1));
    expect(find.text('Create workspace'), findsOneWidget);
    expect(tester.getSize(create), size);
    expect(tester.widget<FilledButton>(create).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byKey(const ValueKey('onboarding-confirm')), findsOneWidget);
    repo.gate.complete();
    await tester.pump();
    await tester.pump();
    expect(repo.workspaces.single.name, 'Kept draft');
    expect(find.byKey(const ValueKey('onboarding-error')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Enter submits once and remains disabled while pending', (tester) async {
    final repo = HeldCreation();
    await ready(tester, repo);
    final create = find.byKey(const ValueKey('onboarding-create'));
    final ink = find.descendant(of: create, matching: find.byType(InkWell));
    final target = find.descendant(of: ink, matching: find.byType(GestureDetector)).first;
    Focus.of(tester.element(target)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(repo.requests, hasLength(1));
    repo.gate.complete();
    await tester.pump();
    await tester.pump();
    expect(repo.workspaces, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  for (final failure in [TimeoutException('lost response'), StateError('refused')]) {
    testWidgets('$failure: inline feedback retains draft and retries the same request', (tester) async {
      final repo = HeldCreation();
      await ready(tester, repo);
      final create = find.byKey(const ValueKey('onboarding-create'));
      await tester.tap(create);
      await tester.pump();
      repo.gate.completeError(failure);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('onboarding-error')), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.textContaining('could not be confirmed'), findsOneWidget);
      expect(find.text('Kept draft'), findsOneWidget);
      repo.gate = Completer<void>();
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pump();
      repo.gate.complete();
      await tester.pump();
      await tester.pump();
      expect(repo.requests, hasLength(2));
      expect(repo.requests.toSet(), hasLength(1));
      expect(repo.workspaces, hasLength(1));
      expect(find.byKey(const ValueKey('onboarding-error')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('disposing the view neither cancels the write nor updates a dead view', (tester) async {
    final repo = HeldCreation();
    await ready(tester, repo);
    await tester.tap(find.byKey(const ValueKey('onboarding-create')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    repo.gate.complete();
    await tester.pump();
    expect(repo.workspaces, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}

// SPDX-License-Identifier: AGPL-3.0-or-later
// #1654: create/join activate the returned workspace, never the first/default
// row. A late join cannot select anything after its account or target changes.
import 'dart:async';
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/data/floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import 'package:deskilo/app/entry_intent.dart';
import 'package:deskilo/app/entry_intents.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/workspace/presentation/screens/onboarding_screen.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import '../../helpers/mock_providers.dart';

class HeldJoin extends FakeWorkspaceRepository {
  HeldJoin() : super.withWorkspace() {
    serverDefaultWorkspaceId = 'ws-1';
  }
  Completer<void>? gate;
  Object? failure;
  @override
  Future<String> joinWorkspace(String code) async {
    await gate?.future;
    if (failure != null) throw failure!;
    final id = await super.joinWorkspace(code);
    this.myMember = this.myMember.copyWith(workspaceId: id);
    return id;
  }
}

Future<ProviderContainer> pumpStart(WidgetTester tester, HeldJoin repo,
    {FakeAuthRepository? auth, bool nativeApp = false,
    FakeFloorPlanRepository? plans, FakeReservationRepository? reservations}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(routes: [GoRoute(path: '/',
    builder: (_, _) => const OnboardingScreen()),
    GoRoute(path: '/reserve', builder: (_, _) => const SizedBox()),
    GoRoute(path: '/money', builder: (_, _) => const SizedBox())]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: standardTestOverrides(workspace: repo, auth: auth,
      floorPlan: plans, reservations: reservations),
    child: nativeApp ? const DeskiloApp() : MaterialApp.router(routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales)));
  await tester.pumpAndSettle();
  if (nativeApp) {
    final appRouter = GoRouter.of(tester.element(find.byType(Scaffold).first));
    unawaited(appRouter.push<void>('/onboarding'));
    await tester.pumpAndSettle();
  }
  final container = ProviderScope.containerOf(
    tester.element(find.byType(OnboardingScreen)));
  final authSubscription = container.listen(authStateProvider, (_, _) {});
  addTearDown(authSubscription.close);
  await tester.pumpAndSettle();
  expect(container.read(authStateProvider).value, 'user-1');
  container.read(activeWorkspaceIdProvider);
  await tester.pumpAndSettle();
  expect(container.read(activeWorkspaceIdProvider).value, 'ws-1');
  await container.read(activeBackendProvider.future);
  return container;
}

Future<void> join(WidgetTester tester) async {
  await tester.tap(find.text('Join a workspace'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField), 'GOODCODE22');
  await tester.tap(find.widgetWithText(FilledButton, 'Join'));
  await tester.pump();
}

void main() {
  testWidgets('join selects the returned B even when A is first and default',
      (tester) async {
    final repo = HeldJoin();
    final container = await pumpStart(tester, repo);
    await join(tester);
    await tester.pumpAndSettle();
    final joined = repo.workspaces.last.id;
    expect(joined, isNot('ws-1'));
    expect(container.read(activeWorkspaceIdProvider).value, joined);
    expect(repo.serverDefaultWorkspaceId, 'ws-1');
    expect((await container.read(currentWorkspaceProvider.future))?.id, joined);
    expect(tester.takeException(), isNull);
  });

  testWidgets('native join returns to B guidance and opens the existing date picker',
      (tester) async {
    final repo = HeldJoin();
    final plans = FakeFloorPlanRepository()..seedSmallPlan()
      ..seedSmallPlan(workspaceId: 'ws-joined-1');
    repo.openWeekdays['ws-joined-1'] = const [1, 2, 3, 4, 5, 6, 7];
    final reservations = FakeReservationRepository();
    await pumpStart(tester, repo, nativeApp: true, plans: plans,
      reservations: reservations);
    await join(tester);
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('Get started in Joined Space'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('getting-started-primary')));
    await tester.tap(find.byKey(const ValueKey('getting-started-primary')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(reservations.createCalls, 0);
  });

  testWidgets('creation selects its returned B rather than the old default',
      (tester) async {
    final repo = HeldJoin();
    final container = await pumpStart(tester, repo);
    await tester.enterText(find.byKey(const ValueKey('onboarding-name')), 'New B');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('onboarding-use-suggested')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-create')));
    await tester.pumpAndSettle();
    final created = repo.workspaces.last.id;
    expect(created, isNot('ws-1'));
    expect(container.read(activeWorkspaceIdProvider).value, created);
    expect((await container.read(currentWorkspaceProvider.future))?.id, created);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an explicit original task keeps its workspace and continuation',
      (tester) async {
    final repo = HeldJoin();
    final container = await pumpStart(tester, repo);
    await container.read(entryIntentsProvider.notifier).capture(
      const EntryIntent.openValidated('original-task', '/money'));
    await join(tester);
    await tester.pumpAndSettle();
    expect(repo.workspaces, hasLength(2));
    expect(container.read(activeWorkspaceIdProvider).value, 'ws-1');
    expect(container.read(entryIntentsProvider)?.destination, '/money');
  });

  testWidgets('a late refusal does not show an error on the replacement context',
      (tester) async {
    final repo = HeldJoin()..gate = Completer<void>()..failure = StateError('refused');
    final auth = FakeAuthRepository.signedIn();
    await pumpStart(tester, repo, auth: auth);
    await join(tester);
    await auth.signOut();
    await tester.pumpAndSettle();
    repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onboarding-error')), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(repo.workspaces, hasLength(1));
  });

  for (final change in ['account', 'account round trip', 'installation', 'workspace', 'task']) {
    testWidgets('late join cannot retarget after $change changes', (tester) async {
      final repo = HeldJoin()..gate = Completer<void>();
      final auth = FakeAuthRepository.signedIn();
      final container = await pumpStart(tester, repo, auth: auth);
      await join(tester);
      switch (change) {
        case 'account': await auth.signOut();
        case 'account round trip':
          await auth.signOut();
          auth.signInAs('user-1');
        case 'task':
          await container.read(entryIntentsProvider.notifier).capture(
            const EntryIntent.openValidated('new-task', '/money'));
        case 'installation':
          await container.read(activeBackendProvider.notifier).setEndpoint(
            const BackendEndpoint('https://other.example.org', 'public'));
          await container.read(activeBackendProvider.future);
        case 'workspace':
          await container.read(activeWorkspaceIdProvider.notifier).select('ws-other');
      }
      await tester.pumpAndSettle();
      final before = container.read(activeWorkspaceIdProvider).value;
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(container.read(activeWorkspaceIdProvider).value, before);
      expect(tester.takeException(), isNull);
    });
  }
}

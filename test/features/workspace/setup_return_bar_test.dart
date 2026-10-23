// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2869 — a screen opened from the setup guide carries the way back to it,
// and the bar is gone once the owner is back on the guide.
import 'dart:async';

import 'package:deskilo/app/entry_resumption.dart';
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/features/workspace/domain/setup_status.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_guide_screen.dart';
import 'package:deskilo/features/workspace/presentation/widgets/setup_return_bar.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

final _status = SetupStatus.fromJson({
  'steps': [
    {
      'step': 'places',
      'milestone': 'bookable',
      'required': true,
      'state': 'needs_configuration',
      'route': '/editor',
    },
  ],
  'milestones': [
    {
      'milestone': 'bookable',
      'applies': true,
      'required': 1,
      'ready': 0,
      'reached': false,
    },
  ],
});

void main() {
  testWidgets('the screen a step opens leads back to the guide', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/setup',
      routes: [
        GoRoute(path: '/setup', builder: (_, _) => const SetupGuideScreen()),
        GoRoute(
          path: '/editor',
          builder: (_, _) => const Scaffold(body: Text('editor')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          localSetup: FakeLocalSetupRepository(status: _status),
        ),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) =>
              SetupReturnBar(router: router, child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('setup-return-bar')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('setup-guide-next-places')));
    await tester.pumpAndSettle();
    expect(find.text('editor'), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-return-bar')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('setup-return')));
    await tester.pumpAndSettle();
    expect(find.byType(SetupGuideScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-return-bar')), findsNothing);
    // The way back was taken: the step's push never answers, so the flag
    // is lowered by the bar itself, or the bar would come back later.
    expect(
      ProviderScope.containerOf(tester.element(find.byType(SetupGuideScreen)))
          .read(setupReturnPendingProvider),
      isFalse,
    );
  });

  // #2870 — the bar comes and goes without the router noticing: a tree
  // above the navigator that changed shape rebuilt the Router, which
  // restored the stack from the location last reported, so Back from a
  // step opened the step again.
  testWidgets('Back from a step opened over another screen lands on the '
      'guide, and the step stays closed', (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const Text('home')),
        GoRoute(path: '/setup', builder: (_, _) => const SetupGuideScreen()),
        GoRoute(
          path: '/editor',
          builder: (_, _) =>
              Scaffold(appBar: AppBar(), body: const Text('editor')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          localSetup: FakeLocalSetupRepository(status: _status),
        ),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) =>
              SetupReturnBar(router: router, child: child!),
        ),
      ),
    );
    await _frames(tester);
    // The guide opens over another screen, as it does over Reserve.
    unawaited(router.push('/setup'));
    await _frames(tester);
    for (var visit = 0; visit < 2; visit++) {
      await tester.tap(find.byKey(const ValueKey('setup-guide-next-places')));
      await _frames(tester);
      expect(find.text('editor'), findsOneWidget);
      expect(find.byKey(const ValueKey('setup-return-bar')), findsOneWidget);

      await tester.tap(find.byType(BackButton).hitTestable());
      await _frames(tester);
      expect(find.text('editor'), findsNothing, reason: 'visit $visit');
      expect(find.byType(SetupGuideScreen), findsOneWidget);
    }
  });

  // #2870 — the app's router re-reads where the person is whenever a
  // membership, a feature or the session changes. #2911 — the refresh
  // keeps the step's page and its push's answer, so the guide reads the
  // status again on the way back, and the bar goes.
  testWidgets('a router refresh while a step is open: Back still reads the '
      'status again and lowers the bar', (tester) async {
    final local = FakeLocalSetupRepository(status: _status);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const Text('home')),
        GoRoute(path: '/setup', builder: (_, _) => const SetupGuideScreen()),
        GoRoute(
          path: '/editor',
          builder: (_, _) =>
              Scaffold(appBar: AppBar(), body: const Text('editor')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(localSetup: local),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) =>
              SetupReturnBar(router: router, child: child!),
        ),
      ),
    );
    await _frames(tester);
    unawaited(router.push('/setup'));
    await _frames(tester);
    await tester.tap(find.byKey(const ValueKey('setup-guide-next-places')));
    await _frames(tester);

    // The step did its work, and the app's router refreshed meanwhile.
    local.status = _placesReady;
    reaskRedirect(router);
    await _frames(tester);
    expect(find.text('editor'), findsOneWidget);

    await tester.tap(find.byType(BackButton).hitTestable());
    await _frames(tester);
    expect(find.byType(SetupGuideScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-guide-all-done')), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-return-bar')), findsNothing);
  });

  // #2912 — the onboarding hand-off pushes the guide over Reserve, so the
  // location the router reports is /reserve while the guide is on top.
  testWidgets('the bar is hidden on the guide pushed over Reserve, with a '
      'step in progress, and shows on any screen above it', (tester) async {
    final router = GoRouter(
      initialLocation: '/reserve',
      routes: [
        GoRoute(path: '/reserve', builder: (_, _) => const Text('reserve')),
        GoRoute(path: '/setup', builder: (_, _) => const SetupGuideScreen()),
        GoRoute(
          path: '/editor',
          builder: (_, _) =>
              Scaffold(appBar: AppBar(), body: const Text('editor')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          localSetup: FakeLocalSetupRepository(status: _status),
        ),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) =>
              SetupReturnBar(router: router, child: child!),
        ),
      ),
    );
    await _frames(tester);
    unawaited(router.push('/setup'));
    await _frames(tester);
    expect(router.routeInformationProvider.value.uri.path, '/reserve',
        reason: 'the reported location is the route under the push');
    final pending = ProviderScope.containerOf(
      tester.element(find.byType(SetupReturnBar)),
    ).read(setupReturnPendingProvider.notifier)..set(open: true);
    await _frames(tester);
    expect(find.byType(SetupGuideScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-return-bar')), findsNothing);

    unawaited(router.push('/editor'));
    await _frames(tester);
    expect(find.byKey(const ValueKey('setup-return-bar')), findsOneWidget);

    await tester.tap(find.byType(BackButton).hitTestable());
    await _frames(tester);
    expect(find.byType(SetupGuideScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-return-bar')), findsNothing);
    pending.set(open: false);
  });

  // #2870 — the bar comes and goes without the router noticing: a tree
  // above the navigator that changed shape rebuilt the Router, which
  // restored the stack from the location last reported, so Back from a
  // step opened the step again.
  testWidgets('Back from a step opened over another screen lands on the '
      'guide, and the step stays closed', (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const Text('home')),
        GoRoute(path: '/setup', builder: (_, _) => const SetupGuideScreen()),
        GoRoute(
          path: '/editor',
          builder: (_, _) =>
              Scaffold(appBar: AppBar(), body: const Text('editor')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          localSetup: FakeLocalSetupRepository(status: _status),
        ),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) =>
              SetupReturnBar(router: router, child: child!),
        ),
      ),
    );
    await _frames(tester);
    // The guide opens over another screen, as it does over Reserve.
    unawaited(router.push('/setup'));
    await _frames(tester);
    for (var visit = 0; visit < 2; visit++) {
      await tester.tap(find.byKey(const ValueKey('setup-guide-next-places')));
      await _frames(tester);
      expect(find.text('editor'), findsOneWidget);
      expect(find.byKey(const ValueKey('setup-return-bar')), findsOneWidget);

      await tester.tap(find.byType(BackButton).hitTestable());
      await _frames(tester);
      expect(find.text('editor'), findsNothing, reason: 'visit $visit');
      expect(find.byType(SetupGuideScreen), findsOneWidget);
    }
  });

  // #2870 — the app's router re-reads where the person is whenever a
  // membership, a feature or the session changes, and rebuilds the stack
  // from it: the step's push never answers then. The guide still reads
  // the status again on the way back, and the bar still goes.
  testWidgets('a router refresh while a step is open: Back still reads the '
      'status again and lowers the bar', (tester) async {
    final local = FakeLocalSetupRepository(status: _status);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const Text('home')),
        GoRoute(path: '/setup', builder: (_, _) => const SetupGuideScreen()),
        GoRoute(
          path: '/editor',
          builder: (_, _) =>
              Scaffold(appBar: AppBar(), body: const Text('editor')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(localSetup: local),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) =>
              SetupReturnBar(router: router, child: child!),
        ),
      ),
    );
    await _frames(tester);
    unawaited(router.push('/setup'));
    await _frames(tester);
    await tester.tap(find.byKey(const ValueKey('setup-guide-next-places')));
    await _frames(tester);

    // The step did its work, and the app's router refreshed meanwhile.
    local.status = _placesReady;
    reportCurrentLocation(router);
    router.refresh();
    await _frames(tester);
    expect(find.text('editor'), findsOneWidget);

    await tester.tap(find.byType(BackButton).hitTestable());
    await _frames(tester);
    expect(find.byType(SetupGuideScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-guide-all-done')), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-return-bar')), findsNothing);
  });
}

/// A second of frames: a page transition and the fake's answers.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

final _placesReady = SetupStatus.fromJson({
  'steps': [
    {
      'step': 'places',
      'milestone': 'bookable',
      'required': true,
      'state': 'ready',
      'route': '/editor',
    },
  ],
  'milestones': [
    {
      'milestone': 'bookable',
      'applies': true,
      'required': 1,
      'ready': 1,
      'reached': true,
    },
  ],
});

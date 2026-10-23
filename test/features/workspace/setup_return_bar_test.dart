// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2869 — a screen opened from the setup guide carries the way back to it,
// and the bar is gone once the owner is back on the guide.
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
  });
}

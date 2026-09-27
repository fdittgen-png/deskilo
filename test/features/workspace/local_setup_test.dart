// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1656 group 5 — the local setup a template needs is named at creation,
// and what a space still lacks is listed in settings with where to fill
// it in; a complete space shows nothing.
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/features/workspace/domain/local_setup.dart';
import 'package:deskilo/features/workspace/presentation/widgets/local_setup_views.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

Future<List<String>> _pump(
  WidgetTester tester,
  Widget child,
  FakeLocalSetupRepository repo,
) async {
  final pushed = <String>[];
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: child),
      ),
      GoRoute(
        path: '/payment-config',
        builder: (_, _) {
          pushed.add('/payment-config');
          return const Scaffold();
        },
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(localSetup: repo),
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return pushed;
}

void main() {
  test('slots read the server words; unknown ones are kept aside', () {
    final slots = LocalSlot.listFromJson([
      {
        'slot': 'legal_identity',
        'required': true,
        'route': '/settings',
        'filled': false,
      },
      {'slot': 'payment_details', 'required': false, 'route': 'javascript:x'},
      {'slot': 'weird'},
    ]);
    expect(slots.map((s) => s.kind), [
      LocalSlotKind.legalIdentity,
      LocalSlotKind.paymentDetails,
      LocalSlotKind.unknown,
    ]);
    expect(
      slots[1].route,
      '/settings',
      reason: 'only in-app routes are followed',
    );
    expect(slots[1].filled, isNull);
  });

  testWidgets('creation names what the template will need', (tester) async {
    await _pump(
      tester,
      const TemplateLocalNeedsView(templateId: 't'),
      FakeLocalSetupRepository(
        needs: {
          't': const [
            LocalSlot(
              kind: LocalSlotKind.legalIdentity,
              required: true,
              route: '/settings',
            ),
            LocalSlot(
              kind: LocalSlotKind.paymentDetails,
              required: false,
              route: '/settings',
            ),
          ],
        },
      ),
    );
    expect(
      find.byKey(const ValueKey('template-local-need-legalIdentity')),
      findsOneWidget,
    );
    expect(find.text('Recommended'), findsOneWidget);
  });

  testWidgets(
    'settings lists only what is missing, and opens where to fill it',
    (tester) async {
      final pushed = await _pump(
        tester,
        const LocalReadinessCard(workspaceId: 'ws'),
        FakeLocalSetupRepository(
          missing: const [
            LocalSlot(
              kind: LocalSlotKind.legalIdentity,
              required: true,
              route: '/settings',
              filled: true,
            ),
            LocalSlot(
              kind: LocalSlotKind.paymentProvider,
              required: true,
              route: '/payment-config',
              filled: false,
            ),
          ],
        ),
      );
      expect(
        find.byKey(const ValueKey('local-gap-legalIdentity')),
        findsNothing,
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('local-gap-paymentProvider')),
          matching: find.byType(TextButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(pushed, ['/payment-config']);
    },
  );

  testWidgets('a complete space shows nothing', (tester) async {
    await _pump(
      tester,
      const LocalReadinessCard(workspaceId: 'ws'),
      FakeLocalSetupRepository(),
    );
    expect(find.byKey(const ValueKey('local-readiness')), findsNothing);
  });
}

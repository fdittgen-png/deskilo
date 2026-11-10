// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step F -- a space before joining: a picture or an initial, its name and
// address, its kind, then ONE filled action (Ask to join) and an outlined
// Message the space, with the line saying what asking shares. A visitor who is
// not signed in is led to sign-in by the primary action.
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/presentation/public_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

PublicWorkspace _space() =>
    const PublicWorkspace('ws-1', 'https://host.example', 'k', {
      'name': 'Atelier Nord',
      'address': '12 rue Haute, 34120 Pézenas',
      'host_type': 'company',
      'description': 'A quiet studio.',
    });

Future<GoRouter> _pump(WidgetTester tester, {required bool signedIn}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => PublicWorkspaceView(workspace: _space()),
      ),
      GoRoute(
        path: '/auth',
        builder: (_, _) => const Scaffold(body: Text('sign-in page')),
      ),
    ],
  );
  await pumpApp(
    tester,
    null,
    router: router,
    size: const Size(390, 1400),
    overrides: standardTestOverrides(
      auth: signedIn ? FakeAuthRepository.signedIn() : FakeAuthRepository(),
      // The page reads the card again from its installation.
      directory: FakeDirectoryRepository()..cards.add(_space()),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets(
    'the page orders initial, name, address, kind, one filled action, '
    'Message the space, the privacy line',
    (tester) async {
      await _pump(tester, signedIn: true);
      Finder k(String key) => find.byKey(ValueKey(key));
      final initial = tester.getTopLeft(k('public-workspace-initial')).dy;
      final name = tester
          .getTopLeft(
            find.descendant(
              of: find.byType(ListView),
              matching: find.text('Atelier Nord'),
            ),
          )
          .dy;
      final address = tester.getTopLeft(k('public-workspace-address')).dy;
      final install = tester.getTopLeft(k('public-workspace-installation')).dy;
      final kind = tester.getTopLeft(k('public-workspace-run-by')).dy;
      final ask = tester.getTopLeft(k('portal-request-membership')).dy;
      final message = tester.getTopLeft(k('write-to-hosts')).dy;
      final privacy = tester.getTopLeft(k('public-workspace-privacy')).dy;
      expect(
        [initial, name, address, install, kind, ask, message, privacy],
        orderedEquals(
          [
            ...[initial, name, address, install, kind, ask, message, privacy],
          ]..sort(),
        ),
      );
      expect(find.text('Ask to join'), findsOneWidget);
      expect(find.text('Send a message'), findsOneWidget);
      expect(find.text('Run by a company'), findsOneWidget);
      expect(
        find.text('host.example'),
        findsOneWidget,
        reason: 'the installation the place comes from, under the address',
      );
      expect(find.byType(FilledButton), findsOneWidget);
      expect(
        find.text(
          'Nothing is shared until you ask. Then they see your name and photo, nothing else.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('a visitor who is not signed in is led to sign-in', (
    tester,
  ) async {
    await _pump(tester, signedIn: false);
    await tester.tap(find.byKey(const ValueKey('portal-request-membership')));
    await tester.pumpAndSettle();
    expect(find.text('sign-in page'), findsOneWidget);
  });
}

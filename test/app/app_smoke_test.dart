// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The app boots: a signed-in user with a space lands in the shell on the
// Reserve hub (/reserve), a signed-out one on the auth screen.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_screen.dart';
import 'package:deskilo/features/reservations/presentation/screens/reserve_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/mock_providers.dart';

void main() {
  testWidgets('signed-in user with a space boots into that space on the '
      'Reserve hub', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();

    // #1862 — the route and the screen actually shown, not a label that
    // exists somewhere offstage. #1823: a person whose last space is
    // valid enters it; the router's initial location is /reserve.
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    expect(router.state.uri.path, '/reserve');
    expect(find.byType(ShellScreen), findsOneWidget);
    expect(find.byType(ReserveScreen), findsOneWidget);
  });

  testWidgets('signed-out user lands on the auth screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(auth: FakeAuthRepository()),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
  });
}

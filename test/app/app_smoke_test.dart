// SPDX-License-Identifier: 0BSD
import 'package:deskilo/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';

void main() {
  testWidgets('signed-in user boots into the shell with Messages as the first tab',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();

    // #687 — the first destination is Messages now; the plan moved to
    // Réserver, which draws the same canvas.
    expect(find.text('Messages'), findsWidgets);
    expect(
      find.text('The workspace has no floor plan yet.'),
      findsOneWidget,
    );
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

// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';

void main() {
  testWidgets('signed-in user boots into the shell on the Plan tab',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plan'), findsWidgets);
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

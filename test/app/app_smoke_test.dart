// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DeskiloApp boots into the shell on the Plan tab',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DeskiloApp()));
    await tester.pumpAndSettle();

    expect(find.text('Plan'), findsWidgets);
    expect(find.text('Coming soon'), findsOneWidget);
  });
}

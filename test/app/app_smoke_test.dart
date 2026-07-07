// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DeskiloApp boots inside a ProviderScope', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DeskiloApp()));

    expect(find.text('DesKilo'), findsOneWidget);
  });
}

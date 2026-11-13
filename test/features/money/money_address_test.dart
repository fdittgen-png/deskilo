// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3627 — the money page keeps its face and its month in the address
// (`/money?face=<name>&month=yyyy-MM`), written without a new history
// entry: an address names what is shown, and choosing writes it.
import 'package:deskilo/features/money/domain/money_face.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/screens/money_faces.dart';

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byKey(const ValueKey('money-faces'))));

String _period(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

void main() {
  testWidgets('choosing a face writes it to the address; an address naming '
      'one shows it', (tester) async {
    await pumpFaces(tester);
    await face(tester, MoneyFace.invoices);
    expect(_router(tester).state.uri.queryParameters['face'], 'invoices');

    _router(tester).go('/money?face=usage');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('money-face-body-usage')), findsOneWidget);
  });

  testWidgets('the month is in the address: an earlier one is written, and '
      'an address naming one is the month shown', (tester) async {
    await pumpFaces(tester);
    await tester.tap(find.byKey(const ValueKey('money-chevron-left')));
    await tester.pumpAndSettle();
    final before = DateTime(kTestNow.year, kTestNow.month - 1);
    expect(_router(tester).state.uri.queryParameters['month'], _period(before));

    _router(tester).go('/money?month=2025-12');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('money-chevron-right')));
    await tester.pumpAndSettle();
    expect(_router(tester).state.uri.queryParameters['month'], '2026-01');
  });
}

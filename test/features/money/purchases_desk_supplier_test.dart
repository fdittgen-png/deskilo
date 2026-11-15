// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4067 — the purchases table's supplier cell: the supplier's name, "No
// supplier" for a purchase that has none, "Not read" when the suppliers could
// not be read; never a blank. At desk width (the table) and at phone width
// (the cards); sorting and search keep working on the names.
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/presentation/screens/purchases_desk.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

PurchaseSummary _doc(String id, {String? supplierId}) => PurchaseSummary(
  id: id,
  kind: PurchaseKind.bill,
  state: PurchaseState.approved,
  category: 'Cat $id',
  reference: 'REF-$id',
  currency: 'EUR',
  grossCents: 1000,
  supplierId: supplierId,
);

final _docs = [_doc('a', supplierId: 's1'), _doc('b')];

Future<void> _open(
  WidgetTester tester,
  Size size, {
  required Future<List<Supplier>> Function() suppliers,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(
          body: PurchasesDesk(workspaceId: 'ws', held: {}, doors: []),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await pumpApp(
    tester,
    null,
    router: router,
    size: size,
    locale: const Locale('en'),
    overrides: [
      ...standardTestOverrides(),
      purchasesProvider.overrideWith((ref, ws) async => _docs),
      payablesProvider.overrideWith((ref, ws) async => const []),
      suppliersProvider.overrideWith((ref, ws) => suppliers()),
    ],
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

const _desk = Size(1400, 900);
const _phone = Size(390, 844);

Future<List<Supplier>> _read() async => const [
  Supplier(id: 's1', number: '1', name: 'Atelier Martin'),
];

Future<List<Supplier>> _failed() async => throw StateError('refused');

void main() {
  for (final (label, size) in [('desk', _desk), ('phone', _phone)]) {
    testWidgets('$label: a purchase without a supplier says "No supplier"', (
      tester,
    ) async {
      await _open(tester, size, suppliers: _read);
      expect(find.text('Atelier Martin'), findsOneWidget);
      expect(find.text('No supplier'), findsOneWidget);
      expect(find.text('Not read'), findsNothing);
      final muted = tester.widget<Text>(find.text('No supplier'));
      expect(muted.style?.color, isNotNull, reason: 'it is muted text');
    });

    testWidgets('$label: unread suppliers say "Not read", never a blank', (
      tester,
    ) async {
      await _open(tester, size, suppliers: _failed);
      expect(find.text('Not read'), findsOneWidget);
      expect(find.text('No supplier'), findsOneWidget);
      expect(find.text('Atelier Martin'), findsNothing);
    });
  }

  testWidgets('search finds a purchase by its supplier name', (tester) async {
    await _open(tester, _desk, suppliers: _read);
    final search = find.byType(TextField);
    expect(search, findsWidgets);
    await tester.enterText(search.first, 'martin');
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Atelier Martin'), findsOneWidget);
    expect(find.text('No supplier'), findsNothing);
  });
}

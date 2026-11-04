// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 4 — a bill line names the catalogue item it bought, how many
// and in what unit: offered while the purchase figures are on, refused
// without a quantity above zero, sent to the server with the line, and
// absent while the figures are off.
import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/money/presentation/widgets/purchases_sheet.dart';
import 'package:deskilo/features/money/providers/credit_providers.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

const _coffee = ServiceItem(
  id: 'svc-coffee',
  workspaceId: 'ws',
  name: 'Coffee capsules',
  priceCents: 200,
  active: true,
  stock: 40,
);

Widget _app(FakePurchaseRepository repo, {required bool figures}) => _scope([
  purchaseRepositoryProvider.overrideWithValue(repo),
  memberLabelsProvider.overrideWithValue({}),
  spaceCurrencyProvider.overrideWithValue('EUR'),
  servicesProvider.overrideWith((ref) async => const [_coffee]),
  enabledFeaturesSyncProvider.overrideWithValue({
    if (figures) WorkspaceFeature.purchaseAnalytics,
  }),
]);

Widget _scope(List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: PurchasesView(
          workspaceId: 'ws',
          canCapture: true,
          canDecide: true,
        ),
      ),
    ),
  ),
);

Future<void> _step(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('purchase-save')));
  await tester.tap(find.byKey(const ValueKey('purchase-save')));
  await _step(tester);
}

void main() {
  test('the line sends its item, quantity and unit, and keeps them', () {
    const line = PurchaseLineDraft(
      grossCents: 3000,
      item: PurchaseItem(serviceId: 'svc-coffee', quantity: 100, unit: 'box'),
    );
    expect(line.toJson(), containsPair('service_id', 'svc-coffee'));
    expect(line.toJson(), containsPair('quantity', 100.0));
    expect(line.toJson(), containsPair('unit', 'box'));
    final stored = line.toLine(1);
    expect(
      (stored.serviceId, stored.quantity, stored.unit),
      ('svc-coffee', 100.0, 'box'),
    );
    expect(
      const PurchaseLineDraft(grossCents: 1).toJson().containsKey('service_id'),
      isFalse,
    );
  });

  test('the server line reads its item back', () {
    final line = PurchaseLine.fromJson({
      'line_no': 1,
      'description': 'Coffee',
      'gross_cents': 3000,
      'service_id': 'svc-coffee',
      'quantity': 100,
      'unit': 'box',
    });
    expect(
      (line.serviceId, line.quantity, line.unit),
      ('svc-coffee', 100.0, 'box'),
    );
  });

  testWidgets('a bill names its item; without a quantity it is not saved', (
    tester,
  ) async {
    final repo = FakePurchaseRepository();
    await tester.pumpWidget(_app(repo, figures: true));
    await _step(tester);
    await tester.tap(find.byKey(const ValueKey('purchase-add-bill')));
    await _step(tester);
    await tester.enterText(find.byKey(const ValueKey('purchase-gross')), '30');
    await tester.ensureVisible(find.byKey(const ValueKey('purchase-item')));
    await tester.tap(find.byKey(const ValueKey('purchase-item')));
    await _step(tester);
    await tester.tap(find.text('Coffee capsules').last);
    await _step(tester);
    await _save(tester);
    expect(find.byKey(const ValueKey('purchase-invalid')), findsOneWidget);
    expect(await repo.fetchPurchases('ws'), isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('purchase-quantity')),
      '100',
    );
    await tester.enterText(find.byKey(const ValueKey('purchase-unit')), 'box');
    await _save(tester);
    final saved = (await repo.fetchPurchases('ws')).single;
    final line = (await repo.fetchDetail('ws', saved.id)).lines.single;
    expect(
      (line.serviceId, line.quantity, line.unit),
      ('svc-coffee', 100.0, 'box'),
    );
  });

  testWidgets('with the purchase figures off, no item is asked', (
    tester,
  ) async {
    await tester.pumpWidget(_app(FakePurchaseRepository(), figures: false));
    await _step(tester);
    await tester.tap(find.byKey(const ValueKey('purchase-add-bill')));
    await _step(tester);
    expect(find.byKey(const ValueKey('purchase-item')), findsNothing);
  });
}

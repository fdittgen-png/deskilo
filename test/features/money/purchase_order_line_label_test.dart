// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4078 — in the purchase-order form a line's label ("Line 1") stands above
// its first field with a gap of its own: the field's box begins
// below the label, with and without the line's remove button, on a phone at 320 and
// 390 px with text at 1.0 and 1.3.
import 'package:deskilo/core/demo/data/purchase_order_repository.dart';
import 'package:deskilo/core/demo/data/supplier_repository.dart';
import 'package:deskilo/core/theme/app_spacing.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/purchase_order_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/purchase_orders_app.dart';

const _workspace = Workspace(
  id: 'ws',
  name: 'Space',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'x',
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// The rect of the one paragraph that reads [text] on screen.
Rect _rectOf(WidgetTester tester, String text) =>
    tester.getRect(find.text(text).first);

void main() {
  for (final width in const [320.0, 390.0]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets('at ${width.toInt()} px and text $scale the line label '
          'stands above its field', (tester) async {
        tester.view
          ..physicalSize = Size(width, 1600)
          ..devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final suppliers = FakeSupplierRepository();
        await tester.pumpWidget(
          purchaseOrdersApp([
            currentWorkspaceProvider.overrideWith((ref) async => _workspace),
            myMemberProvider.overrideWith((ref) async => null),
            myPermissionsProvider.overrideWithValue({
              WorkspacePermission.managePurchases,
            }),
            enabledFeaturesSyncProvider.overrideWithValue({
              WorkspaceFeature.purchases,
              WorkspaceFeature.purchaseOrders,
            }),
            supplierRepositoryProvider.overrideWithValue(suppliers),
            purchaseOrderRepositoryProvider.overrideWithValue(
              FakePurchaseOrderRepository(
                suppliers: () => suppliers.suppliers,
                services: () => const [],
                now: () => DateTime(2026, 11, 4),
              ),
            ),
            servicesProvider.overrideWith((ref) async => const <ServiceItem>[]),
          ]),
        );
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('purchase-order-new')));
        await _settle(tester);
        final add = find.byKey(const ValueKey('purchase-order-add-line'));
        await tester.ensureVisible(add);
        await _settle(tester);

        // One line, then two: the second line has its remove button.
        for (var round = 0; round < 2; round++) {
          for (var i = 0; i < 1 + round; i++) {
            final item = find.descendant(
              of: find.byKey(ValueKey('purchase-order-item-$i')),
              matching: find.byType(InputDecorator),
            );
            await tester.ensureVisible(item);
            await tester.pump();
            final label = _rectOf(tester, 'Line ${i + 1}');
            final field = tester.getRect(item);
            expect(
              field.top - label.bottom,
              greaterThanOrEqualTo(AppSpacing.sm),
              reason:
                  'line ${i + 1} (round $round): label $label touches '
                  'its field $field',
            );
          }
          await tester.ensureVisible(add);
          await tester.tap(add);
          await _settle(tester);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}

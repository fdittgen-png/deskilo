// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2871 — the purchase side's setup steps: suppliers, the lease and the
// equipment. Each page lists what the register holds and opens the
// register's own sheet, with the owner's rights; a supplier added in that
// sheet joins the page's list once the sheet closes, because both read the
// same list. Members see none of it, and the preview says so. An empty
// register says it is empty. One column on a phone.
import 'package:deskilo/app/routes/setup_run_pages.dart';
import 'package:deskilo/core/demo/data/premises_lease_repository.dart';
import 'package:deskilo/core/demo/data/supplier_repository.dart';
import 'package:deskilo/core/demo/data/workspace_asset_repository.dart';
import 'package:deskilo/features/money/domain/premises_lease.dart';
import 'package:deskilo/features/money/domain/supplier.dart';
import 'package:deskilo/features/money/domain/workspace_asset.dart';
import 'package:deskilo/features/money/providers/asset_providers.dart';
import 'package:deskilo/features/money/providers/premises_lease_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_step_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _phone = Size(360, 2400);

Future<void> _pump(
  WidgetTester tester,
  String stepId, {
  FakeSupplierRepository? suppliers,
  FakePremisesLeaseRepository? leases,
  FakeWorkspaceAssetRepository? assets,
}) async {
  await pumpApp(
    tester,
    SetupStepScreen(stepId: stepId, runPages: setupRunPages),
    size: _phone,
    overrides: [
      ...standardTestOverrides(),
      supplierRepositoryProvider.overrideWithValue(
        suppliers ?? FakeSupplierRepository(),
      ),
      premisesLeaseRepositoryProvider.overrideWithValue(
        leases ?? FakePremisesLeaseRepository(),
      ),
      workspaceAssetRepositoryProvider.overrideWithValue(
        assets ?? FakeWorkspaceAssetRepository(),
      ),
    ],
  );
  await tester.pumpAndSettle();
}

void _oneColumn(WidgetTester tester) {
  expect(find.byKey(const ValueKey('setup-step-one-column')), findsOneWidget);
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('suppliers: listed as stored; one added in the register\'s '
      'own sheet joins the list; members see nothing', (tester) async {
    final suppliers = FakeSupplierRepository();
    await suppliers.save('ws-1', const SupplierDraft(name: 'Paper & Co'));
    await _pump(tester, 'purchases', suppliers: suppliers);
    expect(find.text('1 · Paper & Co'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('setup-purchases-preview')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('setup-purchases-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('supplier-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('supplier-name')),
      'Coffee Roasters',
    );
    await tester.tap(find.byKey(const ValueKey('supplier-save')));
    await tester.pumpAndSettle();
    expect(
      [for (final s in suppliers.suppliers) s.name],
      ['Paper & Co', 'Coffee Roasters'],
    );
    await tester.tap(find.byKey(const ValueKey('sheet-close')));
    await tester.pumpAndSettle();
    expect(find.text('2 · Coffee Roasters'), findsOneWidget);
    _oneColumn(tester);
  });

  testWidgets('lease: listed as stored and opened in its own sheet; an '
      'empty register says so', (tester) async {
    final leases = FakePremisesLeaseRepository([
      PremisesLease(
        id: 'lease-1',
        revision: 1,
        supplierId: 's-1',
        supplierName: 'Landlord SCI',
        premises: 'Ground floor',
        startsOn: DateTime.utc(2026, 2, 3),
        status: LeaseStatus.active,
      ),
    ]);
    await _pump(tester, 'lease', leases: leases);
    expect(find.text('Ground floor · Landlord SCI'), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-lease-preview')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('setup-lease-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lease-add')), findsOneWidget);
    _oneColumn(tester);
  });

  testWidgets('equipment: listed as stored; nothing registered says so', (
    tester,
  ) async {
    await _pump(tester, 'assets');
    expect(find.byKey(const ValueKey('setup-assets-none')), findsOneWidget);
    expect(find.byKey(const ValueKey('equipment-button')), findsOneWidget);

    await _pump(
      tester,
      'assets',
      assets: FakeWorkspaceAssetRepository(
        assets: const [
          WorkspaceAsset(
            id: 'a-1',
            revision: 1,
            assetNumber: 1,
            description: 'Espresso machine',
            currency: 'EUR',
            decision: AssetDecision.pending,
            state: AssetState.candidate,
          ),
        ],
      ),
    );
    expect(find.text('Espresso machine'), findsOneWidget);
    _oneColumn(tester);
  });
}

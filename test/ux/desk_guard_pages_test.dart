// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3605 (desk F4) — the desk guards on their first pages, through the app's
// builder at 1024, 1440 and 1920: /invoices, a records page, and the Me
// overview. With SHEET=1 each writes its sheet at 390 and 1440, light and
// dark, to build/sheets/<module>/ (docs/testing/desk-guards.md).
import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/core/demo/data/supplier_repository.dart';
import 'package:deskilo/core/ui/kit/customer_row.dart';
import 'package:deskilo/core/ui/kit/records_table_parts.dart';
import 'package:deskilo/core/ui/kit/table_line.dart';
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/domain/fee_band.dart';
import 'package:deskilo/features/money/domain/guest_pass.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/money/providers/guest_pass_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_money_repository.dart';
import '../helpers/mock_providers.dart';
import 'experience_guards.dart';

Future<void> _open(WidgetTester tester, String path, Size size) async {
  final features = WorkspaceFeature.values.toSet();
  // A records page is guarded with records on it: one issued invoice.
  final money = FakeMoneyRepository();
  await money.createInvoice(
    workspaceId: 'ws-1',
    memberId: 'member-1',
    period: kTestPeriod,
  );
  // #3615 — one supplier, owed one approved bill.
  final suppliers = FakeSupplierRepository();
  final supplier = await suppliers.save(
    'ws-1',
    const SupplierDraft(name: 'ACME Office'),
  );
  final purchases = FakePurchaseRepository()
    ..payables.add(
      PayableRow(
        obligation: PurchaseObligation(
          id: 'o1',
          purchaseId: 'p1',
          creditorKind: CreditorKind.supplier,
          creditorId: supplier,
          amountCents: 12000,
          currency: 'EUR',
          appliedCents: 0,
          remainingCents: 12000,
        ),
        purchase: PurchaseSummary(
          id: 'p1',
          kind: PurchaseKind.bill,
          state: PurchaseState.approved,
          category: 'Office',
          reference: 'F-2026-11',
          currency: 'EUR',
          grossCents: 12000,
          supplierId: supplier,
          receivedOn: DateTime(2026, 11, 3),
        ),
      ),
    );
  await pumpRoute(
    tester,
    path,
    size: size,
    overrides: [
      supplierRepositoryProvider.overrideWithValue(suppliers),
      purchaseRepositoryProvider.overrideWithValue(purchases),
      ...standardTestOverrides(
        money: money,
        workspace:
            FakeWorkspaceRepository.withWorkspace(
                featureFlags: {for (final f in features) f.name: true},
              )
              // #3618 — a member on a plan, so the members' pages have rows.
              ..otherMembers.add(
                const Member(
                  id: 'member-2',
                  workspaceId: 'ws-1',
                  userId: 'user-2',
                  isAdmin: false,
                  isOwner: false,
                  status: MemberStatus.active,
                  subscriptionPct: 50,
                ),
              )
              ..memberEmails = {'member-2': 'bob@example.test'},
      ),
      enabledFeaturesSyncProvider.overrideWithValue(features),
      guestPassRepositoryProvider.overrideWithValue(_OnePassSold()),
    ],
  );
}

/// A row of the purchases table (purchases_desk.dart), by its shape.
typedef _PurchaseRow = ({PurchaseSummary doc, String supplier, int? open});

/// The pages the guards run on: path, kind, module and screen for a sheet.
const _pages = [
  ('/invoices', PageKind.records, 'money', 'invoices'),
  ('/me', PageKind.dashboard, 'me', 'overview'),
  // #3606 — the first records table.
  ('/invoice-register', PageKind.records, 'money', 'invoice-register'),
  // #3614 — sales at the desk.
  ('/services', PageKind.records, 'money', 'services'),
  ('/money/guest-passes', PageKind.records, 'money', 'guest-passes'),
  // #3615 — purchases at the desk.
  ('/money/purchases', PageKind.records, 'money', 'purchases'),
  ('/money/suppliers', PageKind.records, 'money', 'suppliers'),
  // #3618 — members and plans at the desk, and a member beside the table.
  ('/members', PageKind.records, 'members', 'members'),
  ('/members/member-2', PageKind.records, 'members', 'member'),
  ('/members/plans', PageKind.records, 'members', 'plans'),
];

/// One pass sold, so the guest passes page is guarded with a record on it.
class _OnePassSold implements GuestPassRepository {
  @override
  Future<List<GuestPassOffer>> offers(String workspaceId) async => const [
    GuestPassOffer(
      id: 'day',
      name: 'Day pass',
      unit: GuestPassUnit.day,
      priceCents: 2400,
    ),
  ];

  @override
  Future<List<GuestPassRecord>> passesSold(String workspaceId) async => [
    GuestPassRecord(
      id: 'p1',
      memberId: 'member-1',
      offerId: 'day',
      unit: GuestPassUnit.day,
      units: 2,
      amountCents: 4800,
      startsAt: DateTime(2026, 11, 2, 9),
      endsAt: DateTime(2026, 11, 3, 18),
    ),
  ];

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => loadSheetFonts(always: true));

  for (final (path, kind, module, screen) in _pages) {
    for (final size in deskGuardSizes) {
      testWidgets('$path at ${size.width.toInt()}: the desk guards hold', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await _open(tester, path, size);
        final details = <String>[];
        expect(
          deskGuardProblems(
            details: details,
            tester,
            kind: kind,
            size: size,
            rowTypes: const [
              KitTableLine,
              CustomerRow,
              RecordRow<Invoice>,
              RecordsHeader<Invoice>,
              RecordRow<Receivable>,
              RecordsHeader<Receivable>,
              RecordRow<ServiceItem>,
              RecordsHeader<ServiceItem>,
              RecordRow<GuestPassRecord>,
              RecordsHeader<GuestPassRecord>,
              RecordRow<Supplier>,
              RecordsHeader<Supplier>,
              RecordRow<_PurchaseRow>,
              RecordsHeader<_PurchaseRow>,
              RecordRow<Member>,
              RecordsHeader<Member>,
              RecordRow<FeeBand>,
              RecordsHeader<FeeBand>,
            ],
            tableTypes: const [
              KitTableHeader,
              CustomerHeader,
              RecordsHeader<Invoice>,
              RecordsHeader<Receivable>,
              RecordsHeader<ServiceItem>,
              RecordsHeader<GuestPassRecord>,
              RecordsHeader<Supplier>,
              RecordsHeader<_PurchaseRow>,
              RecordsHeader<Member>,
              RecordsHeader<FeeBand>,
            ],
          ),
          isEmpty,
          reason: details.join('\n'),
        );
        expect(await keyboardProblems(tester), isEmpty);
        semantics.dispose();
      });
    }
    for (final width in [390.0, 1440.0]) {
      for (final brightness in Brightness.values) {
        testWidgets('$path sheet at ${width.toInt()}, ${brightness.name}', (
          tester,
        ) async {
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          await _open(tester, path, Size(width, 900));
          await writeDeskSheet(
            tester,
            module: module,
            screen: screen,
            width: width,
            brightness: brightness,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

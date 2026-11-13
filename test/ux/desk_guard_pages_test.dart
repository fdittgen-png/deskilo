// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3605 (desk F4) — the desk guards on their first pages, through the app's
// builder at 1024, 1440 and 1920: /invoices, a records page, and the Me
// overview. With SHEET=1 each writes its sheet at 390 and 1440, light and
// dark, to build/sheets/<module>/ (docs/testing/desk-guards.md).
import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/core/demo/data/supplier_repository.dart';
import 'package:deskilo/core/ui/adaptive/long_task_page.dart';
import 'package:deskilo/core/ui/adaptive/window_class.dart';
import 'package:deskilo/core/ui/kit/customer_row.dart';
import 'package:deskilo/core/ui/kit/records_table_parts.dart';
import 'package:deskilo/core/ui/kit/table_line.dart';
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/domain/guest_pass.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/money/providers/book_period_providers.dart';
import 'package:deskilo/features/money/providers/guest_pass_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/features/money/providers/vat_declaration_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/presentation/widgets/report_pages.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        workspace: FakeWorkspaceRepository.withWorkspace(
          featureFlags: {for (final f in features) f.name: true},
        ),
      ),
      enabledFeaturesSyncProvider.overrideWithValue(features),
      guestPassRepositoryProvider.overrideWithValue(_OnePassSold()),
      // #3616 — the books: one closed quarter and its file; one return.
      bookPeriodRepositoryProvider.overrideWithValue(_OneQuarter()),
      vatDeclarationsProvider.overrideWith((ref) async => [_return]),
      vatTaxPointsTodayProvider.overrideWith((ref) async => const []),
    ],
  );
}

/// A row of the purchases table (purchases_desk.dart), by its shape.
typedef _PurchaseRow = ({PurchaseSummary doc, String supplier, int? open});
/// One closed quarter, and the file handed out for it.
class _OneQuarter implements BookPeriodRepository {
  @override
  Future<BookPeriodsOverview> fetch(String workspaceId) async =>
      BookPeriodsOverview(
        periods: [
          BookPeriod(
            id: 'q1',
            from: DateTime(2026),
            to: DateTime(2026, 3, 31),
            reason: BookPeriodReason.of('owner'),
          ),
        ],
        exports: [
          BookExport(
            id: 'x1',
            formatId: 'fec',
            from: DateTime(2026),
            to: DateTime(2026, 3, 31),
            sha256: 'ab' * 32,
            byteCount: 2048,
            rowCount: 24,
            documentCount: 6,
            closedPeriod: true,
            exportedAt: DateTime(2026, 4, 3),
          ),
        ],
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// One prepared return of the first quarter.
final _return = VatDeclaration(
  id: 'd1',
  workspaceId: 'ws-1',
  periodStart: DateTime(2026),
  periodEnd: DateTime(2026, 3, 31),
  status: 'prepared',
  lines: const [
    VatDeclarationLine(
      percent: 20,
      grossCents: 12000,
      netCents: 10000,
      vatCents: 2000,
      invoiceCount: 1,
    ),
  ],
  totalNetCents: 10000,
  totalVatCents: 2000,
  currency: 'EUR',
  invoiceCount: 1,
  createdAt: DateTime(2026, 4, 2),
);

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
  // #3616 — the books at the desk.
  ('/money/accounting', PageKind.dashboard, 'money', 'accounting'),
  ('/money/accounting/exports', PageKind.records, 'money', 'accounting-exports'),
  ('/vat-declarations/d1', PageKind.task, 'money', 'vat-return'),
  // #3619 — settings and setup at the desk.
  ('/settings', PageKind.task, 'settings', 'account'),
  ('/workspace-settings', PageKind.task, 'settings', 'workspace'),
  ('/features', PageKind.records, 'settings', 'features'),
  ('/setup/step/basics', PageKind.task, 'settings', 'setup-step'),
  // #3860 — a record open beside its table: the table keeps its staying
  // columns, the pane its reading measure, together the work area.
  (
    '/money/suppliers/demo-supplier-1',
    PageKind.recordBesideTable,
    'money',
    'suppliers-open',
  ),
  (
    '/money/purchases/doc/p1',
    PageKind.recordBesideTable,
    'money',
    'purchases-open',
  ),
  // #3617 — reports and analysis at the desk.
  ('/reports', PageKind.records, 'reports', 'reports'),
  ('/money/status', PageKind.dashboard, 'money', 'status'),
  ('/bi', PageKind.dashboard, 'reports', 'analysis'),
];

/// Pages whose guard waits on the kit, each with its issue. The list only
/// shrinks: the issue's acceptance removes its line.
const _notGuarded = <String, String>{
  '/features':
      '#3891 — a long records table: Tab walks lazily built rows (the '
      'long-table keyboard contract)',
};

/// The same, at one width only ("path@width").
const _notGuardedAt = <String, String>{
  '/setup/step/basics@1024':
      '#3893 — the desk app bar cuts a long title at 1024 before it folds '
      'its actions',
};

/// #3619 — how many workspace routes the guards above hold; it only rises
/// (the follow-up guards the rest, the most used modules first).
const _guardedWorkspaceRoutes = 12;

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
  test('the guarded workspace routes only rise', () {
    final guarded = {
      for (final (path, _, _, _) in _pages)
        if (matchRoute(path) case final r? when r.kind == RouteClass.workspace)
          r.pattern,
    };
    final all = routeRules.where((r) => r.kind == RouteClass.workspace);
    expect(
      guarded.length,
      greaterThanOrEqualTo(_guardedWorkspaceRoutes),
      reason: 'of ${all.length} workspace routes',
    );
    if (guarded.length > _guardedWorkspaceRoutes) {
      fail('raise _guardedWorkspaceRoutes to ${guarded.length}');
    }
  });

  setUpAll(() => loadSheetFonts(always: true));
  // A sheet runs on the real clock, where the records table's read of its
  // saved columns needs a store to answer.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (path, pageKind, module, screen) in _pages) {
    for (final size in deskGuardSizes) {
      // #3860 — below a large window a record opens as a page of its own:
      // there is no table beside it to measure.
      final kind =
          pageKind == PageKind.recordBesideTable &&
              !WindowClass.ofWidth(size.width).atLeast(WindowClass.large)
          ? PageKind.document
          : pageKind;
      testWidgets('$path at ${size.width.toInt()}: the desk guards hold', (
        tester,
      ) async {
        // A named exception is said, never a silent pass.
        final exception =
            _notGuarded[path] ?? _notGuardedAt['$path@${size.width.toInt()}'];
        if (exception != null) {
          markTestSkipped(exception);
          return;
        }
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
              RecordRow<BookExport>,
              RecordsHeader<BookExport>,
              RecordRow<FeatureManifestEntry>,
              RecordsHeader<FeatureManifestEntry>,
              RecordRow<ReportPage>,
              RecordsHeader<ReportPage>,
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
              RecordsHeader<BookExport>,
              RecordsHeader<FeatureManifestEntry>,
              RecordsHeader<ReportPage>,
            ],
          ),
          isEmpty,
          reason: details.join('\n'),
        );
        // A long task (#3608) is its own focus scope: Tab walks the page.
        // A record beside its table is two Tab groups; the cycle's wrap
        // through the shell is its own follow-up, not this row's rule.
        // #3619 — a settings form is a task page that is not a long task.
        final longTask = find.byType(LongTaskPage);
        if (kind != PageKind.recordBesideTable) {
          expect(
            await keyboardProblems(
              tester,
              within: longTask.evaluate().isNotEmpty ? longTask : null,
            ),
            isEmpty,
          );
        }
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

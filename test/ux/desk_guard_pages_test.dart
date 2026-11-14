// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3605 (desk F4) — the desk guards on their first pages, through the app's
// builder at 1024, 1440 and 1920: /invoices, a records page, and the Me
// overview. With SHEET=1 each writes its sheet at 390 and 1440, light and
// dark, to build/sheets/<module>/ (docs/testing/desk-guards.md).
import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/core/demo/data/purchase_approval_reads.dart';
import 'package:deskilo/core/demo/data/purchase_order_repository.dart';
import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/core/demo/data/supplier_repository.dart';
import 'package:deskilo/core/demo/seed/demo_setup_status.dart';
import 'package:deskilo/core/ui/adaptive/long_task_page.dart';
import 'package:deskilo/core/ui/adaptive/window_class.dart';
import 'package:deskilo/core/ui/kit/customer_row.dart';
import 'package:deskilo/core/ui/kit/records_table_parts.dart';
import 'package:deskilo/core/ui/kit/table_line.dart';
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/domain/fee_band.dart';
import 'package:deskilo/features/money/domain/guest_pass.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/domain/purchase_order.dart';
import 'package:deskilo/features/money/domain/recorded_payments.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/money/domain/usage_record.dart';
import 'package:deskilo/features/money/providers/book_period_providers.dart';
import 'package:deskilo/features/money/providers/guest_pass_providers.dart';
import 'package:deskilo/features/money/providers/purchase_approval_provider.dart';
import 'package:deskilo/features/money/providers/purchase_order_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/features/money/providers/vat_declaration_providers.dart';
import 'package:deskilo/features/profile/domain/rights_request.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
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
import '../helpers/fake_profile_repository.dart';
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
  // #3627 — the money pages are guarded with their own records on them: the
  // invoice paid (the payments page's row), one credit and one booking. The
  // invoices page keeps its unpaid invoice.
  if (path.startsWith('/money')) {
    final paid = money.invoices.single;
    money.invoiceMatchesStore[paid.id] = InvoiceMatch(
      invoiceId: paid.id,
      paidCents: paid.totalCents,
      resolution: 'exact',
      paymentLedgerId: 'payment-1',
      matchedAt: kTestNow,
    );
    money.ledger.add(
      LedgerEntry(
        id: 'credit-1',
        memberId: 'member-1',
        kind: LedgerKind.credit,
        category: LedgerCategory.payment,
        amountCents: 5000,
        description: 'Transfer',
        period: kTestPeriod,
        createdAt: kTestNow,
      ),
    );
    money.usageRecords.add(
      UsageRecord(
        id: 'usage-1',
        memberId: 'member-1',
        reservationId: 'res-1',
        period: kTestPeriod,
        reservedFrom: kTestNow,
        reservedTo: kTestNow.add(const Duration(hours: 4)),
        countedMinutes: 240,
        reservedMinutes: 240,
        spaceLabel: 'Desk A1',
      ),
    );
  }
  // #3615 — one supplier, owed one approved bill.
  final suppliers = FakeSupplierRepository();
  final supplier = await suppliers.save(
    'ws-1',
    const SupplierDraft(name: 'ACME Office'),
  );
  // #3842 — one order to that supplier, so the orders page has a row and
  // an order to open beside it.
  final orders = FakePurchaseOrderRepository(
    suppliers: () => suppliers.suppliers,
    services: () => const [],
    now: () => kTestNow,
  );
  await orders.save(
    'ws-1',
    'guard-order',
    PurchaseOrderDraft(
      supplierId: supplier,
      lines: const [
        PurchaseOrderLineDraft(
          description: 'Coffee beans',
          quantity: 6,
          unitPriceCents: 1450,
        ),
      ],
    ),
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
    )
    // #3874 — a bill waiting for a second person, so the approvals page
    // has a row.
    ..addPendingBill(
      PurchaseDetail(
        summary: PurchaseSummary(
          id: 'p2',
          kind: PurchaseKind.bill,
          state: PurchaseState.pending,
          category: 'Cleaning',
          reference: 'F-2026-12',
          currency: 'EUR',
          grossCents: 4800,
          supplierId: supplier,
          receivedOn: DateTime(2026, 11, 5),
        ),
        revision: 1,
        lines: const [
          PurchaseLine(
            lineNo: 1,
            description: 'Office cleaning, November',
            grossCents: 4800,
          ),
        ],
        sources: const [],
      ),
    );
  await pumpRoute(
    tester,
    path,
    size: size,
    overrides: [
      supplierRepositoryProvider.overrideWithValue(suppliers),
      purchaseOrderRepositoryProvider.overrideWithValue(orders),
      purchaseRepositoryProvider.overrideWithValue(purchases),
      purchaseApprovalReadsProvider.overrideWithValue(
        FakePurchaseApprovalReads(purchases),
      ),
      ...standardTestOverrides(
        money: money,
        // #3629 — the guide's pages with the Demo's setup state: every
        // feature on, the basics and the hours done.
        localSetup: path.startsWith('/setup')
            ? FakeLocalSetupRepository(
                status: demoSetupStatus(
                  {for (final f in features) f.name: true},
                  ready: {'basics', 'hours'},
                ),
              )
            : null,
        // #3628 — a request waiting, so the privacy page has a row.
        profile: FakeProfileRepository()
          ..rightsRequests.add(
            RightsRequest(
              id: 'rr-1',
              workspaceId: 'ws-1',
              memberId: 'member-1',
              kind: 'access',
              status: 'received',
              receivedAt: DateTime(2026, 11, 9),
              dueOn: DateTime(2026, 12, 9),
              details: 'a copy of what you hold',
            ),
          ),
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
  // #3892 — booking and requests at the desk.
  // #3947 — controls named, targets of the kit's size.
  ('/accessories', PageKind.document, 'money', 'accessories'),
  ('/documents', PageKind.document, 'reports', 'documents'),
  // #3943 — an empty page passes the keyboard on.
  ('/reservations/period', PageKind.document, 'booking', 'period'),
  // #3892 — settings, people, money and documents at the desk.
  ('/validation', PageKind.task, 'requests', 'validation'),
  ('/assistants/connect', PageKind.task, 'settings', 'assistants-connect'),
  ('/settings/assistants', PageKind.task, 'settings', 'assistants'),
  ('/settings/assistant-setup', PageKind.task, 'settings', 'assistant-setup'),
  ('/kiosk-gate', PageKind.task, 'kiosk', 'kiosk-gate'),
  ('/kiosk', PageKind.task, 'kiosk', 'kiosk'),
  ('/pending', PageKind.document, 'account', 'pending'),
  ('/plan', PageKind.document, 'places', 'plan'),
  ('/badge-kiosks', PageKind.task, 'settings', 'badge-kiosks'),
  ('/accounting/connected', PageKind.document, 'money', 'accounting-connected'),
  ('/suppliers', PageKind.records, 'money', 'suppliers-alias'),
  ('/deployment', PageKind.task, 'settings', 'deployment'),
  ('/editor', PageKind.task, 'places', 'editor'),
  ('/money/repartition-wizard', PageKind.task, 'money', 'repartition-wizard'),
  ('/members/privacy/rr-1', PageKind.recordBesideTable, 'people', 'privacy-open'),
  ('/settings/payment-terms', PageKind.task, 'settings', 'payment-terms'),
  ('/settings/questions', PageKind.task, 'settings', 'questions'),
  ('/settings/roles-of-this-space', PageKind.document, 'settings', 'roles-of-this-space'),
  ('/formats', PageKind.task, 'settings', 'formats'),
  ('/payment-config', PageKind.task, 'settings', 'payment-config'),
  ('/nfc-config', PageKind.task, 'settings', 'nfc-config'),
  ('/workspace-code', PageKind.document, 'settings', 'workspace-code'),
  ('/members/managed', PageKind.task, 'people', 'managed'),
  ('/money/cash', PageKind.document, 'money', 'cash'),
  ('/vat-declarations', PageKind.document, 'money', 'vat-declarations'),
  ('/library', PageKind.document, 'reports', 'library'),
  ('/setup/levels', PageKind.task, 'settings', 'setup-levels'),
  ('/attention', PageKind.document, 'booking', 'attention'),
  ('/events', PageKind.document, 'requests', 'events'),
  ('/invoices', PageKind.records, 'money', 'invoices'),
  ('/me', PageKind.dashboard, 'me', 'overview'),
  // #3606 — the first records table.
  ('/invoice-register', PageKind.records, 'money', 'invoice-register'),
  // #3614 — sales at the desk.
  ('/services', PageKind.records, 'money', 'services'),
  ('/money/guest-passes', PageKind.records, 'money', 'guest-passes'),
  // #3615 — purchases at the desk.
  ('/money/purchases', PageKind.records, 'money', 'purchases'),
  // #3874 — what waits for a decision.
  (
    '/money/purchases/approvals',
    PageKind.records,
    'money',
    'purchase-approvals',
  ),
  ('/money/suppliers', PageKind.records, 'money', 'suppliers'),
  // #3842 — the purchase orders as records, and an order beside the table.
  ('/money/purchase-orders', PageKind.records, 'money', 'purchase-orders'),
  (
    '/money/purchase-orders/order/demo-order-1',
    PageKind.recordBesideTable,
    'money',
    'purchase-orders-open',
  ),
  // #3618 — members and plans at the desk, and a member beside the table.
  ('/members', PageKind.records, 'members', 'members'),
  ('/members/plans', PageKind.records, 'members', 'plans'),
  // #3860 — a member open beside the table: name, state and what is open stay.
  ('/members/member-2', PageKind.recordBesideTable, 'members', 'member-open'),
  // #3616 — the books at the desk.
  ('/money/accounting', PageKind.dashboard, 'money', 'accounting'),
  ('/money/accounting/exports', PageKind.records, 'money', 'accounting-exports'),
  // #3627 — the payments received at the desk.
  ('/money/payments', PageKind.records, 'money', 'payments'),
  // #3627 — my money at the desk: the month a dashboard, the faces tables.
  ('/money?face=statement', PageKind.dashboard, 'money', 'money-month'),
  ('/money?face=invoices', PageKind.records, 'money', 'money-invoices'),
  ('/money?face=payments', PageKind.records, 'money', 'money-payments'),
  ('/money?face=usage', PageKind.records, 'money', 'money-usage'),
  ('/vat-declarations/d1', PageKind.task, 'money', 'vat-return'),
  // #3619 — settings and setup at the desk.
  ('/settings', PageKind.task, 'settings', 'account'),
  ('/workspace-settings', PageKind.task, 'settings', 'workspace'),
  ('/features', PageKind.records, 'settings', 'features'),
  ('/setup/step/basics', PageKind.task, 'settings', 'setup-step'),
  // #3629 — the setup guide at the desk: its steps beside a step with a
  // preview, beside a step done on its own screen, and beside Launch.
  ('/setup/step/assistant', PageKind.task, 'settings', 'setup-step-elsewhere'),
  ('/setup/launch', PageKind.task, 'settings', 'setup-launch'),
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
  // #3628 — the roles beside the chosen role's permissions.
  ('/roles', PageKind.document, 'people', 'roles'),
  ('/members/privacy', PageKind.records, 'people', 'privacy-requests'),
];

/// #3619 — how many workspace routes the guards above hold; it only rises
/// (the follow-up guards the rest, the most used modules first).
const _guardedWorkspaceRoutes = 59;

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
              RecordRow<BookExport>,
              RecordsHeader<BookExport>,
              RecordRow<FeatureManifestEntry>,
              RecordsHeader<FeatureManifestEntry>,
              RecordRow<ReportPage>,
              RecordsHeader<ReportPage>,
              RecordRow<RightsRequest>,
              RecordsHeader<RightsRequest>,
              RecordRow<RecordedPayment>,
              RecordsHeader<RecordedPayment>,
              RecordRow<LedgerEntry>,
              RecordsHeader<LedgerEntry>,
              RecordRow<UsageRecord>,
              RecordsHeader<UsageRecord>,
              RecordRow<PurchaseOrder>,
              RecordsHeader<PurchaseOrder>,
              RecordRow<PurchaseSummary>,
              RecordsHeader<PurchaseSummary>,
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
              RecordsHeader<BookExport>,
              RecordsHeader<FeatureManifestEntry>,
              RecordsHeader<ReportPage>,
              RecordsHeader<RightsRequest>,
              RecordsHeader<RecordedPayment>,
              RecordsHeader<LedgerEntry>,
              RecordsHeader<UsageRecord>,
              RecordsHeader<PurchaseOrder>,
              RecordsHeader<PurchaseSummary>,
            ],
          ),
          isEmpty,
          reason: details.join('\n'),
        );
        // A long task (#3608) is its own focus scope: Tab walks the page. A
        // record beside its table is walked with the shell around it (#3891).
        // #3619 — a settings form is a task page that is not a long task.
        final longTask = find.byType(LongTaskPage);
        expect(
          await keyboardProblems(
            tester,
            within: longTask.evaluate().isNotEmpty ? longTask : null,
          ),
          isEmpty,
        );
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

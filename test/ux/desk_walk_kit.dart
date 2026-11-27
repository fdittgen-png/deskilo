// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3605 (desk F4) — the desk guards on their first pages, through the app's
// builder at 1024, 1440 and 1920: /invoices, a records page, and the Me
// overview. With SHEET=1 each writes its sheet at 390 and 1440, light and
// dark, to build/sheets/<module>/ (docs/testing/desk-guards.md).
import 'dart:io';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/demo/data/fake_organisation_repository.dart';
import 'package:deskilo/core/demo/data/floor_plan_repository.dart';
import 'package:deskilo/core/demo/data/kpi_repositories.dart';
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/core/demo/data/purchase_approval_reads.dart';
import 'package:deskilo/core/demo/data/purchase_order_repository.dart';
import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/core/demo/data/reservation_repository.dart';
import 'package:deskilo/core/demo/data/supplier_repository.dart';
import 'package:deskilo/core/demo/seed/demo_setup_status.dart';
import 'package:deskilo/core/ui/adaptive/long_task_page.dart';
import 'package:deskilo/core/ui/adaptive/window_class.dart';
import 'package:deskilo/core/ui/kit/customer_row.dart';
import 'package:deskilo/core/ui/kit/records_table_parts.dart';
import 'package:deskilo/core/ui/kit/table_line.dart';
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/application/receivables_answers.dart';
import 'package:deskilo/features/money/domain/fee_band.dart';
import 'package:deskilo/features/money/domain/guest_pass.dart';
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
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/bi_report_definition.dart';
import 'package:deskilo/features/workspace/domain/bi_saved_view.dart';
import 'package:deskilo/features/workspace/domain/conversation.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/member_note.dart';
import 'package:deskilo/features/workspace/domain/organisation_overview.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/presentation/widgets/report_pages.dart';
import 'package:deskilo/features/workspace/providers/kpi_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_money_repository.dart';
import '../helpers/fake_profile_repository.dart';
import '../helpers/mock_providers.dart';
import 'experience_guards.dart';
import 'walked_routes.dart';

/// #4007 — the organisation the overview page is guarded with: a head in
/// euros and a house in pounds, both with figures.
FakeOrganisationRepository _twoHouses() {
  OverviewHouse house(String id, String name, String country, String currency,
          {bool head = false}) =>
      OverviewHouse(
        workspaceId: id,
        name: name,
        countryCode: country,
        currencyCode: currency,
        isHead: head,
        invoiced: const HouseFigure(minor: 125000),
        collected: const HouseFigure(minor: 98000),
        overdue: HouseFigure(minor: 12000, asOf: kTestNow),
      );
  return FakeOrganisationRepository(
    overviewOf: (organisation, month) async => OrganisationOverview.ofHouses(
      organisationId: organisation,
      month: month,
      houses: [
        house('ws-1', 'Atelier du Marché', 'FR', 'EUR', head: true),
        house('ws-3', 'Camden Yard', 'GB', 'GBP'),
      ],
    ),
  );
}

/// #4076 -- who looks at the page: the fixture's own owner, or an
/// administrator or a plain member of the same space (the identities of the
/// router's golden, test/app/fixtures/route_outcomes.golden).
enum WalkPersona {
  owner(isAdmin: true, isOwner: true),
  admin(isAdmin: true, isOwner: false),
  member(isAdmin: false, isOwner: false);

  const WalkPersona({required this.isAdmin, required this.isOwner});

  final bool isAdmin;
  final bool isOwner;

  FakeWorkspaceRepository seen(FakeWorkspaceRepository repo) {
    repo.myMember = repo.myMember.copyWith(isAdmin: isAdmin, isOwner: isOwner);
    return repo;
  }
}

Future<void> openWalkPage(
  WidgetTester tester,
  String path,
  Size size, [
  WalkPersona persona = WalkPersona.owner,
]) async {
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
  // #3949 — the places, one booking and one saved report, for the record
  // pages opened at their address (only there: the other pages keep the
  // fixture they were measured with).
  final records = const [
    '/res/',
    '/space/',
    '/editor/level/',
    '/reservations/period?',
    '/bi/report/',
  ].any(path.startsWith);
  final plan = FakeFloorPlanRepository()..seedSmallPlan();
  final bookings = FakeReservationRepository()
    ..reservations.add(
      Reservation(
        id: 'res-1',
        workspaceId: 'ws-1',
        seatId: 'seat-4',
        memberId: 'member-1',
        startsAt: kTestNow,
        endsAt: kTestNow.add(const Duration(hours: 4)),
        status: ReservationStatus.reserved,
      ),
    );
  // One saved report (view-1): the seat use as a figure, from the booking.
  final views = InMemoryBiViewRepository();
  await views.save(
    'ws-1',
    scope: BiViewScope.private,
    name: 'Seat use',
    definition: BiViewDefinition.ofReport(
      BiReportDefinition(
        period: const BiReportPeriod.relative(BiGrain.month, 0),
        pages: [
          BiReportPage(
            id: 'p1',
            title: 'Capacity',
            visuals: [
              BiReportVisual.kpi(
                id: 'v1',
                metricId: 'capacity.seat_utilisation',
                layout: const BiVisualLayout(order: 0, span: 3, height: 1),
              ),
            ],
          ),
        ],
      ),
    ),
    expectedRevision: 0,
  );
  // #3947 — a conversation with a message, for its page.
  final talk = path.startsWith('/conversation/');
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
        // #4007 — an organisation of two houses in two currencies.
        organisations: _twoHouses(),
        floorPlan: records ? plan : null,
        reservations: records ? bookings : null,
        biViews: records ? views : null,
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
        workspace: persona.seen(
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
              ..memberEmails = {'member-2': 'bob@example.test'}
              ..conversations.addAll([
                if (talk)
                  Conversation(
                    id: 'conv-1',
                    kind: ConversationKind.direct,
                    otherMemberId: 'member-2',
                    lastAt: kTestNow,
                  ),
              ])
              ..conversationMessages.addAll({
                if (talk)
                  'conv-1': [
                    MemberNote(
                      id: 'n1',
                      workspaceId: 'ws-1',
                      fromMemberId: 'member-2',
                      toMemberId: 'member-1',
                      body: 'Is the meeting room free on Friday?',
                      createdAt: kTestNow,
                    ),
                  ],
              }),
        ),
      ),
      enabledFeaturesSyncProvider.overrideWithValue(features),
      if (records)
        kpiRepositoryProvider.overrideWithValue(
          DemoCapacityKpiRepository(
            plan: plan,
            reservations: bookings,
            now: kTestNow,
          ),
        ),
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

/// #4022 — the pages the 768 walk found a fault in and the fault; each is
/// left out of that one width until the page is fixed, and walked at every
/// other.
const Map<String, String> waitsAt768 = {};

/// #4077 -- what the owner's desk walk found on the pages it gained and has
/// not fixed: `path|width` -> the measurement. Each case is left out until its
/// page is fixed (the list only shrinks); a test below holds that every key is
/// a case of the walk.
const Map<String, String> deskFindings = {
};


/// The widgets that draw a table row on the pages above, and the widgets a
/// records page's table is (their widest decides the share).
const List<Type> walkRowTypes = [
              KitTableLine,
              CustomerRow,
              RecordRow<Invoice>,
              RecordsHeader<Invoice>,
              RecordRow<Receivable>,
              RecordsHeader<Receivable>,
              RecordRow<CustomerLine>,
              RecordsHeader<CustomerLine>,
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
              RecordRow<OverviewHouse>,
              RecordsHeader<OverviewHouse>,
            ];

const List<Type> walkTableTypes = [
              KitTableHeader,
              CustomerHeader,
              RecordsHeader<Invoice>,
              RecordsHeader<Receivable>,
              RecordsHeader<CustomerLine>,
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
              RecordsHeader<OverviewHouse>,
              RecordsHeader<PurchaseSummary>,
            ];

/// The address the router holds after the page was opened.
String walkLanded(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(DeskiloApp)),
).read(routerProvider).routerDelegate.currentConfiguration.uri.path;

/// #4076 -- the personas the walk adds, and the two sizes it renders them at:
/// one desk and one phone.
const List<WalkPersona> walkedPersonas = [WalkPersona.member, WalkPersona.admin];
const List<Size> walkPersonaSizes = [Size(1440, 900), Size(390, 844)];

/// The router patterns [persona] may open with every feature on, read from the
/// router's own golden: a page the router refuses a persona is not rendered
/// as that persona (the golden holds the refusal).
Set<String> personaOpens(WalkPersona persona) => {
  for (final line in File(
    'test/app/fixtures/route_outcomes.golden',
  ).readAsLinesSync())
    if (RegExp(r'^(\S+) on  (\S+) -> \(open\)$').firstMatch(line)
        case final m? when m.group(1) == persona.name)
      m.group(2)!,
};

/// #4096 — the routes the router's golden says the desk forwards for
/// [persona] (a `@desk` line): there the person lands on another page of
/// theirs, which the walk checks instead.
Set<String> personaDeskForwards(WalkPersona persona) => {
  for (final line in File(
    'test/app/fixtures/route_outcomes.golden',
  ).readAsLinesSync())
    if (RegExp(r'^(\S+) on  (\S+) @desk -> ').firstMatch(line)
        case final m? when m.group(1) == persona.name)
      m.group(2)!,
};

/// #4076 -- what the persona walk found and has not fixed: `path|persona|
/// width` -> the measurement. Each case is left out until its page is fixed
/// (the list only shrinks); a test below holds that every key is a case of the
/// walk, so a fixed page cannot leave a stale line.
const Map<String, String> personaFindings = {
};

/// What kind of page a persona meets: a member's /invoices is the member's own
/// invoices (cards, no table of all invoices and no record beside one), so the
/// desk's records rules do not describe it.
PageKind walkKindFor(WalkPersona persona, String path, PageKind kind) =>
    persona == WalkPersona.member && path.startsWith('/invoices')
    ? PageKind.document
    : kind;

/// The rules a page breaks on a phone: an overflow, more than one filled
/// button, a control under 48 dp or without a name, and a title or line that
/// carries information cut.
Set<String> phoneProblems(WidgetTester tester, List<String> details) {
  for (final node in tappableNodes(tester)) {
    if (targetUnder48(node)) {
      details.add(
        'target ${node.size.width.toStringAsFixed(1)} x '
        '${node.size.height.toStringAsFixed(1)}'
        '${node.named ? '' : ' (unnamed)'} "${node.label}"',
      );
    }
  }
  details.addAll(unnamedControlDetails(tester));
  return {
    ...guardProblems(tester, width: 390),
    ...cutInformationProblems(details: details),
  };
}

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

/// The desk walk of [pages]: the desk guards at the four desk sizes, the
/// sheets of the pictured pages, and the persona walk of what the router
/// opens for an administrator and a member. The walk is one; the lists it
/// runs on are in walked_routes.dart, and two test files each run one list
/// (a single process cannot hold every case in memory).
void runDeskWalk(List<DeskWalkPage> pages, {required bool pictures}) {
  for (final (path, pageKind, module, screen) in pages) {
    final pictured = pictures;
    for (final size in deskGuardSizes) {
      if (size.width == 768 && waitsAt768.containsKey(path)) continue;
      final deskFinding = deskFindings['$path|${size.width.toInt()}'];
      // #3860 — below a large window a record opens as a page of its own:
      // there is no table beside it to measure.
      final kind =
          pageKind == PageKind.recordBesideTable &&
              !WindowClass.ofWidth(size.width).atLeast(WindowClass.large)
          ? PageKind.document
          : pageKind;
      testWidgets('$path at ${size.width.toInt()}: the desk guards hold', skip:
          deskFinding != null, (tester) async {
        final semantics = tester.ensureSemantics();
        await openWalkPage(tester, path, size);
        // #4077 -- a page added to the walk is the page, not where the
        // router sent the owner instead.
        if (!pictured) {
          expect(walkLanded(tester), Uri.parse(path).path, reason: 'owner');
        }
        final details = <String>[];
        expect(
          deskGuardProblems(
            details: details,
            tester,
            kind: kind,
            size: size,
            rowTypes: walkRowTypes,
            tableTypes: walkTableTypes,
          ),
          isEmpty,
          reason: details.join('\n'),
        );
        // A long task (#3608) is its own focus scope: Tab walks the page. A
        // record beside its table is walked with the shell around it (#3891).
        // #3619 — a settings form is a task page that is not a long task.
        // #4113 -- a page that opens its own sheet on arrival (the demo's
        // entry) is walked in that sheet: the page under a modal is out of
        // Tab's reach by design.
        final longTask = find.byType(LongTaskPage);
        final sheet = find.byType(BottomSheet);
        expect(
          await keyboardProblems(
            tester,
            within: longTask.evaluate().isNotEmpty
                ? longTask
                : sheet.evaluate().isNotEmpty
                ? sheet
                : null,
          ),
          isEmpty,
        );
        semantics.dispose();
      });
    }
    // #4077 -- the pictures are those of the first list.
    for (final width in pictured ? [390.0, 1440.0] : <double>[]) {
      for (final brightness in Brightness.values) {
        testWidgets('$path sheet at ${width.toInt()}, ${brightness.name}', (
          tester,
        ) async {
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          await openWalkPage(tester, path, Size(width, 900));
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

  for (final persona in walkedPersonas) {
    final opens = personaOpens(persona);
    final forwards = personaDeskForwards(persona);
    for (final size in walkPersonaSizes) {
      for (final (path, pageKind, _, _) in pages) {
        if (!opens.contains(matchRoute(path)?.pattern)) continue;
        final kind = walkKindFor(
          persona,
          path,
          pageKind == PageKind.recordBesideTable &&
                  !WindowClass.ofWidth(size.width).atLeast(WindowClass.large)
              ? PageKind.document
              : pageKind,
        );
        final finding =
            personaFindings['$path|${persona.name}|${size.width.toInt()}'];
        testWidgets('$path as ${persona.name} at ${size.width.toInt()}: the '
            'guards hold', skip: finding != null, (tester) async {
          final semantics = tester.ensureSemantics();
          await openWalkPage(tester, path, size, persona);
          final landed = walkLanded(tester);
          // #4096 — where the golden says the desk forwards this route, the
          // person lands on another page of the same place (a refusal sends
          // them elsewhere), and that page is the one checked.
          final forwarded =
              size.width >= 1024 &&
              forwards.contains(matchRoute(path)?.pattern) &&
              landed != Uri.parse(path).path;
          if (forwarded) {
            expect(
              Uri.parse(landed).pathSegments.first,
              Uri.parse(path).pathSegments.first,
              reason: 'the desk forwards $path within its place, not away',
            );
          } else {
            expect(
              landed,
              Uri.parse(path).path,
              reason: 'the router opens it for the ${persona.name}',
            );
          }
          final landedKind = forwarded
              ? pages.firstWhere((p) => p.$1 == landed).$2
              : kind;
          final details = <String>[];
          expect(
            size.width >= 1024
                ? deskGuardProblems(
                    details: details,
                    tester,
                    kind: landedKind,
                    size: size,
                    rowTypes: walkRowTypes,
                    tableTypes: walkTableTypes,
                  )
                : phoneProblems(tester, details),
            isEmpty,
            reason: details.join('\n'),
          );
          semantics.dispose();
        });
      }
    }
  }

}

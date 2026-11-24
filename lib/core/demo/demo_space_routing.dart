// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The repositories that hold ONE space's rows, answered per space.
//
// The demo has separate Pézenas, Leipzig, London and New York spaces,
// and most in-memory repositories answer their rows whatever workspace id
// is asked. Each space therefore has its own, and the provider answers
// with the one of the space being looked at — the current workspace, as
// every screen reads it. Switching spaces rebuilds these providers, and
// everything built on them, exactly as a switch does in live mode.
//
// No cycle: the current workspace is read from the LIST repository
// (`workspaceListRepositoryProvider`), which is never routed.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../app/business_day_wiring.dart';
import '../../app/finance_hosts_wiring.dart';
import '../../app/private_values_wiring.dart';
import '../../features/calendar/providers/calendar_providers.dart';
import '../../features/events/providers/event_providers.dart';
import '../../features/me/providers/me_providers.dart'
    show myReservationsSourcesFromMe, pendingAdmissionsFromMe;
import '../../features/money/domain/hmrc_submission.dart';
import '../../features/money/domain/till_drawer.dart' show DrawerSettings;
import '../../features/money/providers/bank_statement_providers.dart';
import '../../features/money/providers/credit_move_providers.dart';
import '../../features/money/providers/credit_providers.dart';
import '../../features/money/providers/guest_pass_providers.dart';
import '../../features/money/providers/hmrc_providers.dart';
import '../../features/money/providers/invoice_original_providers.dart';
import '../../features/money/providers/money_providers.dart';
import '../../features/money/providers/purchase_order_providers.dart';
import '../../features/money/providers/purchase_providers.dart';
import '../../features/money/providers/recorded_payments_providers.dart';
import '../../features/money/providers/settlement_review_providers.dart';
import '../../features/money/providers/standalone_invoice_providers.dart';
import '../../features/money/providers/till_drawer_providers.dart';
import '../../features/money/providers/till_providers.dart';
import '../../features/plan/providers/accessory_providers.dart';
import '../../features/plan/providers/charging_station_providers.dart';
import '../../features/plan/providers/floor_plan_providers.dart';
import '../../features/reservations/providers/reservation_providers.dart';
import '../../features/stock/providers/stock_providers.dart';
import '../../features/workspace/domain/member.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../../features/workspace/providers/kpi_providers.dart';
import '../../features/workspace/providers/settings_providers.dart' show currentSettingsProvider;
import '../../features/workspace/providers/workspace_fields_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../features/workspace/providers/workspace_roles_providers.dart';
import '../settings/settings.dart' show SettingsSet;
import '../storage/resume_place_store.dart';
import '../time/clock.dart';
import 'data/bank_statement_repository.dart';
import 'data/demo_booking_prices.dart';
import 'data/demo_item_groups.dart';
import 'data/demo_stock_candidates.dart';
import 'data/demo_stock_code_resolver.dart';
import 'data/demo_stock_config_commands.dart';
import 'data/demo_stock_cycle_counts.dart';
import 'data/demo_stock_expiry.dart';
import 'data/demo_stock_handling_units.dart';
import 'data/demo_stock_ledger.dart';
import 'data/demo_stock_operations.dart';
import 'data/demo_stock_queries.dart';
import 'data/demo_stock_receiving_commands.dart';
import 'data/demo_stock_registry.dart';
import 'data/demo_stock_reorder.dart';
import 'data/demo_stock_reversals.dart';
import 'data/demo_stock_tags.dart';
import 'data/demo_stock_trace.dart';
import 'data/demo_stock_trace_chain.dart';
import 'data/demo_stock_track_find.dart';
import 'data/demo_stock_where_is.dart';
import 'data/demo_till.dart';
import 'data/demo_till_drawer.dart';
import 'data/finance_kpi_repository.dart';
import 'data/money/demo_credit_moves.dart';
import 'data/money/demo_invoice_goods_catalogue.dart';
import 'data/money/demo_invoice_issue_drafts.dart';
import 'data/money/demo_invoice_original_repository.dart';
import 'data/money/demo_settlement_reviews.dart';
import 'data/money_repository.dart';
import 'data/my_reservations_repository.dart';
import 'data/purchase_order_repository.dart';
import 'data/purchase_repository.dart';
import 'data/series_previewer.dart';
import 'data/workspace_repository.dart' show FakeWorkspaceMembership;
import 'demo_finance_commands.dart';
import 'demo_fixture.dart';
import 'demo_space_pick.dart';

/// Demo's one fictional installation: nothing is verified against a
/// server, and every client borrows the fakes (#1625).
const kDemoInstallationId = '00000000-0000-4000-8000-00000000de30';

/// #2553 — the spaces as the own-reservations read sees them: one
/// installation, read the way a workspace host answers. A space's name is
/// looked up when a page is built, and a space the session no longer lists
/// is named by its id rather than refused.
DemoMyReservationsRepository _myReservations(DemoFixture fixture) =>
    DemoMyReservationsRepository(
      installationId: kDemoInstallationId,
      // #3846 — read at each page: a space is built when its bookings are asked.
      spaces: _everySpace(fixture),
      workspaceName: (id) =>
          fixture.workspaces.workspaces.where((w) => w.id == id).firstOrNull?.name ?? id,
      // #2553 C2 — each space's own zone, as its workspace row holds it (the
      // rows of every space are in the one list).
      workspaceZone: (id) =>
          fixture.workspaces.workspaces.where((w) => w.id == id).firstOrNull?.timezone,
    );

Iterable<DemoReservationSource> _everySpace(DemoFixture fixture) sync* {
  for (final key in DemoSpaceKey.values) {
    final space = fixture.space(key);
    yield (floorPlan: space.floorPlan, reservations: space.reservations);
  }
}

DemoFinanceKpiRepository _cityKpi(DemoFixture fixture, FakeMoneyRepository money) =>
    DemoFinanceKpiRepository(money: money, workspaces: fixture.workspaces, now: fixture.seededAt);

/// Whether [me] is an active administrator or owner of the space.
bool _administers(Member? me) =>
    me != null && me.status == MemberStatus.active && (me.isAdmin || me.isOwner);

/// The per-space overrides of a Demo scope over [fixture]. Each provider
/// answers with the space being looked at, and that space is built when it is
/// first read (#3846): nothing here builds the others.
List<Override> demoSpaceOverrides(DemoFixture fixture) {
  DemoSpaceParts open(Ref ref) => fixture.space(demoOpenSpace(ref));
  FakeMoneyRepository money(Ref ref) => open(ref).money;
  // One of each per space, made when the space is first read in this scope.
  final actions = demoSpacesOf(
    (key) => FakeInvoiceActionCommands(fixture.space(key).money),
  );
  final kpi = demoSpacesOf(
    (key) => _cityKpi(fixture, fixture.space(key).money),
  );
  final payments = demoSpacesOf((key) {
    final space = fixture.space(key);
    return DemoRecordedPaymentsRepository(
      money: space.money,
      workspaces: space.workspaces,
    );
  });
  final drawers = demoSpacesOf((key) => DemoTillDrawer());
  final tills = _demoTills(fixture, drawers);
  final myReservations = _myReservations(fixture);
  final stocks = _DemoStocks(fixture);
  // #3865 — each space's last bank statement lives on the fixture.
  final banks = demoMapSpaces(fixture.stores, (s) => s.bank);
  // #3853 — the stored originals, one store for the Demo's invoices.
  final originals = DemoInvoiceOriginalRepository(
    storedBy: () => fixture.auth.currentUserId,
    now: () => fixture.seededAt,
  );
  return [
    invoiceOriginalRepositoryProvider.overrideWith((ref) => originals),
    workspaceRepositoryProvider.overrideWith((ref) => open(ref).workspaces),
    floorPlanRepositoryProvider.overrideWith((ref) => open(ref).floorPlan),
    // #2631 — rooms, parking areas and chargers live in memory.
    planResourceRepositoryProvider.overrideWith(
      (ref) => open(ref).planResources,
    ),
    chargingStationRepositoryProvider.overrideWith(
      (ref) => open(ref).chargingStations,
    ),
    reservationRepositoryProvider.overrideWith(
      (ref) => open(ref).reservations
        // #3269 -- as on the server, a booking needs makeReservations.
        ..mayBook = (() => ref
            .read(myPermissionsProvider)
            .contains(WorkspacePermission.makeReservations))
        // #3293 -- another member's booking is an administrator's act.
        ..mayActForOthers = (() => _administers(ref.read(myMemberProvider).value))
        ..isActiveMember = ((id) =>
            open(ref).workspaces.memberOf(id)?.status == MemberStatus.active),
    ),
    // #2553 — the visitor's own bookings of both spaces, one installation.
    myReservationsRepositoryProvider.overrideWithValue(myReservations),
    // Where the visitor was last stays inside the demonstration.
    resumePlaceStoreProvider.overrideWithValue(fixture.prefs.resumePlaces),
    // #2553 C3 — View, Check in and Cancel on the fixture's own spaces.
    myReservationActionsProvider.overrideWithValue(
      DemoMyReservationActions(myReservations),
    ),
    // #2553 C2 / #3696 — read for every space the persona's personal home names.
    myReservationsSourcesFromMe, pendingAdmissionsFromMe,
    // #2557 C5 — Me › Finances reads the same hosts; the fixture's spaces
    // are the personal home's own, answered by its own read.
    financeHostsFromMe, financeHomeFromMe, demoFinanceCommands(fixture),
    // #4167 — My businesses names the person's production spaces.
    businessWorkspacesFromApp,
    // #4426 — the money screens offer the business's day.
    businessDayFromApp,
    // #2552 XPRIV-01 — the persona's mask choice, as the app reads it.
    privateValuesFromAccount,
    // #2575
    seriesPreviewerProvider.overrideWith(
      (ref) => FakeSeriesPreviewer(open(ref).reservations),
    ),
    eventRepositoryProvider.overrideWith((ref) => open(ref).events),
    calendarRepositoryProvider.overrideWith((ref) => open(ref).calendar),
    // #2591 — each money port has its own demo adapter over the space's
    // one in-memory store; the facade stays for the tests that read it.
    moneyRepositoryProvider.overrideWith(money),
    // #2380 — the main space's last bank statement; the second has none yet.
    bankStatementRepositoryProvider.overrideWith((ref) {
      return demoPickSpace<FakeBankStatementRepository>(ref, banks)
        ..actingMemberId = (() => fixture.activeMemberId)
        ..mayUnmatch = (() => ref
            .read(myPermissionsProvider)
            .contains(WorkspacePermission.issueInvoices));
    }),
    // #3060 F5 — the register a plain member reads is their own invoices,
    // as on the server.
    invoiceQueriesProvider.overrideWith((ref) {
      return money(ref).invoiceQueries..ownOnlyFor = () {
        final rights = ref.read(myPermissionsProvider);
        if (rights.contains(WorkspacePermission.viewFinances) ||
            rights.contains(WorkspacePermission.issueInvoices)) {
          return null;
        }
        // Unknown yet reads nothing rather than everything.
        return ref.read(myMemberProvider).value?.id ?? '';
      };
    }),
    // #4105 — the Demo's dry run: the essentials, and the parties an issue
    // would store where the space knows them (Milan).
    invoiceIssueDraftsProvider.overrideWith(
      (ref) => DemoInvoiceIssueDrafts(ref.watch(invoiceQueriesProvider)),
    ),
    ..._moneyPortOverrides(money, stocks),
    // #2585
    invoiceActionCommandsProvider.overrideWith(
      (ref) => demoPickSpace(ref, actions),
    ),
    creditRepositoryProvider.overrideWith((ref) => open(ref).credits),
    // #3843 — what each booking of the open space is charged, by the
    // server's rules over the space's own data.
    bookingPriceReadsProvider.overrideWith((ref) {
      final space = open(ref);
      final key = demoOpenSpace(ref);
      return DemoBookingPriceReads(
        reservations: space.reservations,
        plan: space.floorPlan,
        credits: space.credits,
        passes: () => ref.read(guestPassRepositoryProvider).passesSold(key.id),
        statement: space.money.fetchStatement,
        currency: key.currency,
        readsAll: () => ref
            .read(myPermissionsProvider)
            .contains(WorkspacePermission.viewFinances),
        me: () => ref.read(myMemberProvider).value?.id,
      );
    }),
    accessoryRepositoryProvider.overrideWith((ref) => open(ref).accessories),
    workspaceFieldsRepositoryProvider.overrideWith((ref) => open(ref).fields),
    workspaceRolesRepositoryProvider.overrideWith((ref) => open(ref).roles),
    // #1924 — the finance cards sum the space's own invoices and matches,
    // with the server's predicates.
    financeKpiRepositoryProvider.overrideWith((ref) => demoPickSpace(ref, kpi)),
    ..._hmrcOverrides(fixture),
    // #2578 — the payments behind the collected figure, from the same
    // matches the finance cards sum.
    recordedPaymentsRepositoryProvider.overrideWith((ref) => demoPickSpace(ref, payments)),
    ..._tillOverrides(tills, drawers),
    ..._stockTraceOverrides(stocks, tills),
  ];
}

/// The money ports of the space the scope is looking at: each has its own
/// demo adapter over that space's one in-memory store (#2591).
List<Override> _moneyPortOverrides(FakeMoneyRepository Function(Ref ref) money, _DemoStocks stocks) => [
  memberAccountQueriesProvider.overrideWith(
    (ref) => money(ref).accountQueries,
  ),
  memberAccountCommandsProvider.overrideWith(
    (ref) => money(ref).accountCommands,
  ),
  creditMoveRepositoryProvider.overrideWith((ref) => DemoCreditMoves(money(ref))),
  reportTemplateRepositoryProvider.overrideWith(
    (ref) => money(ref).reportTemplates,
  ),
  invoiceCommandsProvider.overrideWith((ref) => money(ref).invoiceCommands),
  standaloneInvoiceCommandsProvider.overrideWith(
    // #4433 -- and sells goods from the business's own goods ledger
    (ref) => money(ref).standaloneInvoiceCommands..goods = stocks.of(ref).ledger,
  ), // #4165
  invoiceGoodsCatalogueProvider.overrideWith((ref) => DemoInvoiceGoodsCatalogue(stocks.of(ref).ledger)),
  taxReportingRepositoryProvider.overrideWith(
    (ref) => money(ref).taxReporting,
  ),
  commercialTermsProvider.overrideWith((ref) => money(ref).commercialTerms),
  expenseRepositoryProvider.overrideWith((ref) => money(ref).expenses),
  dunningRepositoryProvider.overrideWith((ref) => money(ref).dunning),
  billingRulesRepositoryProvider.overrideWith((ref) => money(ref).billing),
  documentNumberingProvider.overrideWith((ref) => money(ref).numbering),
  paymentGatewayRepositoryProvider.overrideWith(
    (ref) => money(ref).paymentGateway,
  ),
  // #3510 — one settlement report waits for review in the Demo.
  settlementReviewsRepositoryProvider.overrideWith(
    (ref) => DemoSettlementReviews(),
  ),
  eInvoiceTransmissionsProvider.overrideWith((ref) => money(ref).eInvoices),
  // #2365
  accountingSourceQueriesProvider.overrideWith(
    (ref) => money(ref).accountingSource,
  ),
  // #4161 — the reference business keeps a small shop stock, and so does the shop (#4365): each business its
  // own goods ledger in memory, made when it is first read and kept for the session. The reference business's
  // purchase orders, deliveries and cycle counts stay its own.
  stockQueriesProvider.overrideWith((ref) => DemoStockQueries(stocks.of(ref).ledger)),
  // #4169 — and edits its units, codes and places in memory.
  stockConfigCommandsProvider.overrideWith((ref) => stocks.of(ref).config),
  // #4294 — and keeps reorder points: two shop items are below theirs, read from that same stock.
  stockReorderProvider.overrideWith((ref) => stocks.of(ref).reorder),
  // #4293 — and keeps a registry of those items: barcode, price, cost, a home address.
  stockRegistryProvider.overrideWith((ref) => stocks.of(ref).registry),
  // #4359 — and resolves a scanned code (a place, an item, a carton) from its own registry and units.
  stockCodeResolverProvider.overrideWith((ref) => stocks.of(ref).codeResolver),
  // #4363 — and keeps tags (an NFC chip on a shelf and on the mugs) in memory.
  stockTagsStoreProvider.overrideWith((ref) => stocks.of(ref).tags),
  // #4435 — and keeps handling units (a pallet and a carton at the main store) over that same ledger.
  stockHandlingUnitsProvider.overrideWith((ref) => stocks.of(ref).units),
  // #4431 — the expiry report answers from the lots the Demo keeps with their dates.
  stockExpiryProvider.overrideWith((ref) => stocks.of(ref).expiry),
  // #4171 — and receives the deliveries of its orders into that stock.
  stockReceivingCommandsProvider.overrideWith(
    (ref) => DemoStockReceivingCommands(
      stocks.of(ref).id,
      ref.watch(purchaseOrderRepositoryProvider) as FakePurchaseOrderRepository,
      stocks.of(ref).config,
      stocks.of(ref).ledger,
      tags: stocks.of(ref).tags,
    ),
  ),
  // #4173 — and traces its goods to the orders they were put away from, and values them.
  stockTraceReaderProvider.overrideWith(
    (ref) => DemoStockTrace(
      stocks.of(ref).id,
      stocks.of(ref).ledger,
      ref.watch(purchaseOrderRepositoryProvider) as FakePurchaseOrderRepository,
      ref.watch(stockReceivingCommandsProvider) as DemoStockReceivingCommands,
      ref.watch(purchaseRepositoryProvider) as FakePurchaseRepository,
    ),
  ),
  // #4170 — and moves, transfers between its sites and takes out of that same stock.
  stockOperationsProvider.overrideWith((ref) => stocks.of(ref).operations),
  // #4172 — and returns, corrects and counts on that same stock.
  stockReversalsProvider.overrideWith((ref) => stocks.of(ref).reversals),
  // #4361 — and keeps item groups: drinks (with hot drinks beneath) and homeware, the syrup keeping its own shelf life.
  itemGroupsProvider.overrideWith((ref) => stocks.of(ref).itemGroups),
  // #4434 — and answers where an item is, now and on a past day, from that same ledger.
  stockWhereIsProvider.overrideWith((ref) => DemoStockWhereIs(stocks.of(ref).ledger, stocks.of(ref).tags)),
  // #4295 — and keeps a cycle count plan for its high-value shelf, whose task counts into those same counts.
  stockCycleCountsProvider.overrideWith(
    (ref) => DemoStockCycleCounts(
      stocks.of(ref).id,
      stocks.of(ref).ledger,
      stocks.of(ref).reversals,
      stocks.of(ref).registry,
      stocks.of(ref).tags,
      () => ref.read(myPermissionsProvider),
      (ref.watch(purchaseOrderRepositoryProvider) as FakePurchaseOrderRepository).now,
    ),
  ),
];

/// #4432 — the whole chain of a lot, from the business's own ledger; #4436 — and of a line its till sold, read
/// backwards, and what carries a track ID: the lots, the pieces and those sales.
List<Override> _stockTraceOverrides(_DemoStocks stocks, DemoSpaces<DemoTill> tills) => [
  stockTraceChainReaderProvider.overrideWith(
    (ref) => DemoStockTraceChain(stocks.of(ref).ledger, sold: () => demoPickSpace(ref, tills).soldLines),
  ),
  stockTrackFinderProvider.overrideWith(
    (ref) => DemoStockTrackFind(
      stocks.of(ref).ledger,
      stocks.of(ref).expiry,
      stocks.of(ref).tags,
      sold: () => demoPickSpace(ref, tills).soldLines,
      held: () => ref.read(myPermissionsProvider),
    ),
  ),
];

/// #4170 / #4365 -- one goods ledger per business: the Stock screen's reads, a delivery put away and every stock
/// command of a business share its own, so what one does the others show. Each is made when its business is first
/// read (the reference business mirrors into the shop: the same four items and places, the same movements).
class _DemoStocks {
  _DemoStocks(this._fixture);

  final DemoFixture _fixture;
  final Map<DemoSpaceKey, _DemoStock> _kits = {};

  _DemoStock of(Ref ref) {
    // the reference business and the shop keep stock; every other business answers as the reference one does for
    // an id that is not its own: nothing (a business that keeps no stock reads as empty)
    final key = demoOpenSpace(ref) == DemoSpaceKey.shop ? DemoSpaceKey.shop : DemoSpaceKey.home;
    return _kits.putIfAbsent(key, () => _DemoStock(_fixture, key, ref.watch(clockProvider).now));
  }
}

class _DemoStock {
  _DemoStock(DemoFixture fixture, DemoSpaceKey key, DateTime Function() now) {
    id = key.id;
    final money = fixture.space(key).money;
    final candidates = DemoStockCandidates(() async => [
      for (final s in await money.fetchServices(id))
        if (s.active) (id: s.id, name: s.name),
    ]);
    config = DemoStockConfigCommands(id, candidates: candidates);
    ledger = DemoStockLedger(id, config, now, candidates);
    registry = DemoStockRegistry(id, ledger, config);
    reorder = DemoStockReorder(id, ledger, config);
    operations = DemoStockOperations(ledger, config);
    reversals = DemoStockReversals(ledger);
    itemGroups = DemoItemGroups(id, config, now);
    tags = DemoStockTags(
      tagModeOf: (item) async => (await itemGroups.effective(id, item)).params['tag_mode']?.value as String?,
      nameOf: (item) async => DemoStockLedger.items.where((i) => i.id == item).firstOrNull?.name,
    );
    codeResolver = DemoStockCodeResolver(id, config, registry, tags);
    units = DemoStockHandlingUnits(ledger);
    expiry = DemoStockExpiry(now, tags, itemsOfGroup: (item, group) async => (await itemGroups.effective(id, item)).groupId == group);
  }

  /// The business this kit belongs to: what every command, trace and count of the kit is scoped to.
  late final String id;
  late final DemoStockConfigCommands config;
  late final DemoStockLedger ledger;
  late final DemoStockRegistry registry;
  late final DemoStockReorder reorder;
  late final DemoStockOperations operations;
  late final DemoStockReversals reversals;
  late final DemoItemGroups itemGroups;
  late final DemoStockTags tags;
  late final DemoStockExpiry expiry;
  late final DemoStockHandlingUnits units;
  late final DemoStockCodeResolver codeResolver;
}

/// #2470 — the HMRC port is the Demo's: nothing leaves the process, so the
/// browser's fraud-prevention values are synthetic too and the journey is the
/// same on every build. London holds it, and is built when it is first read.
List<Override> _hmrcOverrides(DemoFixture fixture) => [
  hmrcRepositoryProvider.overrideWith((ref) => fixture.london.hmrc),
  hmrcClientValuesProvider.overrideWith(
    (ref) async => const HmrcClientValues(
      browserJsUserAgent: 'Demo browser',
      deviceId: 'demo-device',
      timezone: 'UTC+00:00',
      screens: 'width=1280&height=800&scaling-factor=1&colour-depth=24',
      windowSize: 'width=1280&height=720',
      doNotTrack: false,
    ),
  ),
];

/// #4366 — each space's till: its own counter, its own numbers.
/// The till's ports: its sales, its cash drawer (which follows the business's settings and the person's rights, as the server
/// does) and its offline sales, each answered by the space the scope is looking at.
List<Override> _tillOverrides(DemoSpaces<DemoTill> tills, DemoSpaces<DemoTillDrawer> drawers) => [
    tillPortProvider.overrideWith((ref) => demoPickSpace(ref, tills)),
    // #4367 — the drawer follows the business's settings and the person's rights, as the server does.
    tillDrawerPortProvider.overrideWith((ref) {
      return demoPickSpace<DemoTillDrawer>(ref, drawers)
        ..rules = (() => ref.read(currentSettingsProvider).asData?.value == null
            ? const DrawerSettings(blindCount: true, byDenomination: false, reasons: ['change', 'expense', 'other'], paidOutLimitMinor: 0)
            : _drawerSettingsOf(ref.read(currentSettingsProvider).requireValue))
        ..canSeeFinances = (() => ref.read(myPermissionsProvider).contains(WorkspacePermission.viewFinances))
        ..canRecordOutgoing = (() => ref.read(myPermissionsProvider).contains(WorkspacePermission.recordOutgoingPayments))
        ..me = (() => ref.read(myMemberProvider).value?.id ?? 'demo-member');
    }),
    tillOfflinePortProvider.overrideWith((ref) => demoPickSpace(ref, tills)),
];

DemoSpaces<DemoTill> _demoTills(DemoFixture fixture, DemoSpaces<DemoTillDrawer> drawers) => demoSpacesOf(
  (key) => DemoTill(
    drawer: drawers.at(key),
    country: fixture.workspaces.workspaces.firstWhere((w) => w.id == key.id).countryCode,
    currency: key.currency,
    vatPercent: 20,
    // #4436 -- a sale is kept with the Demo's day, so the trace finds it from the track IDs it took
    clock: () => fixture.seededAt,
  ),
);

/// #4367 — the drawer's settings as the business has them.
DrawerSettings _drawerSettingsOf(SettingsSet settings) => DrawerSettings(
  blindCount: settings.read<bool>('counter.blind_count'),
  byDenomination: settings.read<bool>('counter.count_by_denomination'),
  reasons: DrawerSettings.reasonsOf(settings.read<String>('counter.cash_reasons')),
  paidOutLimitMinor: settings.read<int>('counter.paid_out_limit_minor'),
);

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

import '../../app/finance_hosts_wiring.dart';
import '../../app/private_values_wiring.dart';
import '../../features/calendar/providers/calendar_providers.dart';
import '../../features/events/providers/event_providers.dart';
import '../../features/me/providers/me_providers.dart'
    show myReservationsSourcesFromMe, pendingAdmissionsFromMe;
import '../../features/money/domain/hmrc_submission.dart';
import '../../features/money/providers/bank_statement_providers.dart';
import '../../features/money/providers/credit_move_providers.dart';
import '../../features/money/providers/credit_providers.dart';
import '../../features/money/providers/hmrc_providers.dart';
import '../../features/money/providers/money_providers.dart';
import '../../features/money/providers/recorded_payments_providers.dart';
import '../../features/money/providers/settlement_review_providers.dart';
import '../../features/plan/providers/accessory_providers.dart';
import '../../features/plan/providers/charging_station_providers.dart';
import '../../features/plan/providers/floor_plan_providers.dart';
import '../../features/reservations/providers/reservation_providers.dart';
import '../../features/workspace/domain/member.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../../features/workspace/providers/kpi_providers.dart';
import '../../features/workspace/providers/workspace_fields_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../features/workspace/providers/workspace_roles_providers.dart';
import '../storage/resume_place_store.dart';
import 'data/bank_statement_repository.dart';
import 'data/booking_right_reservations.dart';
import 'data/finance_kpi_repository.dart';
import 'data/money/demo_credit_moves.dart';
import 'data/money/demo_settlement_reviews.dart';
import 'data/money_repository.dart';
import 'data/my_reservations_repository.dart';
import 'data/plan_resource_repository.dart';
import 'data/series_previewer.dart';
import 'data/workspace_repository.dart' show FakeWorkspaceMembership;
import 'demo_fixture.dart';
import 'demo_london_space.dart';
import 'demo_space_pick.dart';
import 'demo_trade_city_space.dart';

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
      spaces: [
        for (final key in DemoSpaceKey.values)
          (
            floorPlan: fixture.spaceFloorPlans.at(key),
            reservations: fixture.spaceReservations.at(key),
          ),
      ],
      workspaceName: (id) =>
          fixture.workspaces.workspaces.where((w) => w.id == id).firstOrNull?.name ?? id,
      // #2553 C2 — each space's own zone, as its workspace row holds it.
      workspaceZone: (id) => [
        ...fixture.workspaces.workspaces,
        ...fixture.secondSpace.workspaces.workspaces,
      ].where((w) => w.id == id).firstOrNull?.timezone,
    );

DemoFinanceKpiRepository _cityKpi(DemoFixture fixture, FakeMoneyRepository money) =>
    DemoFinanceKpiRepository(money: money, workspaces: fixture.workspaces, now: fixture.seededAt);

/// Whether [me] is an active administrator or owner of the space.
bool _administers(Member? me) =>
    me != null && me.status == MemberStatus.active && (me.isAdmin || me.isOwner);

/// The per-space overrides of a Demo scope over [fixture].
List<Override> demoSpaceOverrides(DemoFixture fixture) {
  final home = fixture;
  final second = fixture.secondSpace;
  final london = fixture.london;
  final newYork = fixture.newYork;
  final zurich = fixture.zurich;
  final milan = fixture.milan;
  final twin = fixture.twin;
  final homeResources = FakePlanResourceRepository(home.floorPlan);
  final homeActions = FakeInvoiceActionCommands(home.money);
  final secondActions = FakeInvoiceActionCommands(second.money);
  final londonActions = FakeInvoiceActionCommands(london.money);
  final newYorkActions = FakeInvoiceActionCommands(newYork.money);
  FakeMoneyRepository money(Ref ref) =>
      demoPickSpace(ref, (home: home.money, leipzig: second.money, london: london.money, newYork: newYork.money, zurich: zurich.money, milan: milan.money, twin: twin.money));
  final homeKpi = _cityKpi(fixture, home.money);
  final myReservations = _myReservations(fixture);
  final secondKpi = _cityKpi(fixture, second.money);
  final londonKpi = _cityKpi(fixture, london.money);
  final newYorkKpi = _cityKpi(fixture, newYork.money);
  final homePayments = DemoRecordedPaymentsRepository(
    money: home.money,
    workspaces: home.workspaces,
  );
  final secondPayments = DemoRecordedPaymentsRepository(
    money: second.money,
    workspaces: second.workspaces,
  );
  final londonPayments = DemoRecordedPaymentsRepository(
    money: london.money,
    workspaces: london.workspaces,
  );
  final newYorkPayments = DemoRecordedPaymentsRepository(money: newYork.money, workspaces: newYork.workspaces);
  final twinPayments = DemoRecordedPaymentsRepository(money: twin.money, workspaces: twin.workspaces);
  final twinActions = FakeInvoiceActionCommands(twin.money);
  final twinKpi = _cityKpi(fixture, twin.money);
  final zs = _tradeStores(fixture, zurich), ms = _tradeStores(fixture, milan);
  // #3865 — each space's last bank statement lives on the fixture.
  final banks = demoMapSpaces(fixture.stores, (s) => s.bank);
  return [
    workspaceRepositoryProvider.overrideWith(
      (ref) => demoPickSpace(ref, (home: home.workspaces, leipzig: second.workspaces, london: london.workspaces, newYork: newYork.workspaces, zurich: zurich.workspaces, milan: milan.workspaces, twin: twin.workspaces)),
    ),
    floorPlanRepositoryProvider.overrideWith(
      (ref) => demoPickSpace(ref, (home: home.floorPlan, leipzig: second.floorPlan, london: london.floorPlan, newYork: newYork.floorPlan, zurich: zurich.floorPlan, milan: milan.floorPlan, twin: twin.floorPlan)),
    ),
    // #2631 — rooms, parking areas and chargers live in memory.
    planResourceRepositoryProvider.overrideWith(
      (ref) => demoPickSpace(ref, (home: homeResources, leipzig: second.planResources, london: london.planResources, newYork: newYork.planResources, zurich: zurich.planResources, milan: milan.planResources, twin: twin.planResources)),
    ),
    chargingStationRepositoryProvider.overrideWith(
      (ref) => demoPickSpace(ref, (home: home.chargingStations, leipzig: second.chargingStations, london: london.chargingStations, newYork: newYork.chargingStations, zurich: zurich.chargingStations, milan: milan.chargingStations, twin: twin.chargingStations)),
    ),
    reservationRepositoryProvider.overrideWith(
      (ref) => demoPickSpace<RightsCheckedReservationRepository>(ref, (home: home.reservations, leipzig: second.reservations, london: london.reservations, newYork: newYork.reservations, zurich: zurich.reservations, milan: milan.reservations, twin: twin.reservations))
        // #3269 -- as on the server, a booking needs makeReservations.
        ..mayBook = (() => ref
            .read(myPermissionsProvider)
            .contains(WorkspacePermission.makeReservations))
        // #3293 -- another member's booking is an administrator's act.
        ..mayActForOthers = (() => _administers(ref.read(myMemberProvider).value))
        ..isActiveMember = ((id) =>
            demoPickSpace(ref, (home: home.workspaces, leipzig: second.workspaces, london: london.workspaces, newYork: newYork.workspaces, zurich: zurich.workspaces, milan: milan.workspaces, twin: twin.workspaces))
                .memberOf(id)
                ?.status ==
            MemberStatus.active),
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
    financeHostsFromMe,
    // #2552 XPRIV-01 — the persona's mask choice, as the app reads it.
    privateValuesFromAccount,
    // #2575
    seriesPreviewerProvider.overrideWith(
      (ref) => FakeSeriesPreviewer(
        demoPickSpace(ref, (home: home.reservations, leipzig: second.reservations, london: london.reservations, newYork: newYork.reservations, zurich: zurich.reservations, milan: milan.reservations, twin: twin.reservations)),
      ),
    ),
    eventRepositoryProvider.overrideWith(
      (ref) => demoPickSpace(ref, (home: home.events, leipzig: second.events, london: london.events, newYork: newYork.events, zurich: zurich.events, milan: milan.events, twin: twin.events)),
    ),
    calendarRepositoryProvider.overrideWith(
      (ref) => demoPickSpace(ref, (home: home.calendar, leipzig: second.calendar, london: london.calendar, newYork: newYork.calendar, zurich: zurich.calendar, milan: milan.calendar, twin: twin.calendar)),
    ),
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
    ..._moneyPortOverrides(money),
    // #2585
    invoiceActionCommandsProvider.overrideWith(
      (ref) => demoPickSpace(ref, (home: homeActions, leipzig: secondActions, london: londonActions, newYork: newYorkActions, zurich: zs.actions, milan: ms.actions, twin: twinActions)),
    ),
    creditRepositoryProvider.overrideWith(
      (ref) => demoPickSpace(ref, (home: home.credits, leipzig: second.credits, london: london.credits, newYork: newYork.credits, zurich: zurich.credits, milan: milan.credits, twin: twin.credits)),
    ),
    accessoryRepositoryProvider.overrideWith(
      (ref) => demoPickSpace(ref, (home: home.accessories, leipzig: second.accessories, london: london.accessories, newYork: newYork.accessories, zurich: zurich.accessories, milan: milan.accessories, twin: twin.accessories)),
    ),
    workspaceFieldsRepositoryProvider.overrideWith(
      (ref) => demoPickSpace(ref, (home: home.fields, leipzig: second.fields, london: london.fields, newYork: newYork.fields, zurich: zurich.fields, milan: milan.fields, twin: twin.fields)),
    ),
    workspaceRolesRepositoryProvider.overrideWith(
      (ref) => demoPickSpace(ref, (home: home.roles, leipzig: second.roles, london: london.roles, newYork: newYork.roles, zurich: zurich.roles, milan: milan.roles, twin: twin.roles)),
    ),
    // #1924 — the finance cards sum the space's own invoices and matches,
    // with the server's predicates.
    financeKpiRepositoryProvider.overrideWith(
      (ref) => demoPickSpace(ref, (home: homeKpi, leipzig: secondKpi, london: londonKpi, newYork: newYorkKpi, zurich: zs.kpi, milan: ms.kpi, twin: twinKpi)),
    ),
    ..._hmrcOverrides(london),
    // #2578 — the payments behind the collected figure, from the same
    // matches the finance cards sum.
    recordedPaymentsRepositoryProvider.overrideWith(
      (ref) => demoPickSpace(ref, (home: homePayments, leipzig: secondPayments, london: londonPayments, newYork: newYorkPayments, zurich: zs.payments, milan: ms.payments, twin: twinPayments)),
    ),
  ];
}

/// The money ports of the space the scope is looking at: each has its own
/// demo adapter over that space's one in-memory store (#2591).
List<Override> _moneyPortOverrides(FakeMoneyRepository Function(Ref ref) money) => [
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
];

/// #2470 — the HMRC port is the Demo's: nothing leaves the process, so the
/// browser's fraud-prevention values are synthetic too and the journey is the
/// same on every build.
List<Override> _hmrcOverrides(DemoLondonData london) => [
  hmrcRepositoryProvider.overrideWith((ref) => london.hmrc),
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

/// #3832 - what a trade city's money answers with: its invoice actions, its
/// finance figures and its recorded payments.
({
  FakeInvoiceActionCommands actions,
  DemoFinanceKpiRepository kpi,
  DemoRecordedPaymentsRepository payments,
})
_tradeStores(DemoFixture fixture, DemoTradeCityData city) => (
  actions: FakeInvoiceActionCommands(city.money),
  kpi: _cityKpi(fixture, city.money),
  payments: DemoRecordedPaymentsRepository(money: city.money, workspaces: city.workspaces),
);

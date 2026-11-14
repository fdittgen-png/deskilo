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
import '../../features/money/providers/guest_pass_providers.dart';
import '../../features/money/providers/hmrc_providers.dart';
import '../../features/money/providers/money_providers.dart';
import '../../features/money/providers/recorded_payments_providers.dart';
import '../../features/money/providers/settlement_review_providers.dart';
import '../../features/plan/providers/accessory_providers.dart';
import '../../features/plan/providers/charging_station_providers.dart';
import '../../features/plan/providers/floor_plan_providers.dart';
import '../../features/reservations/providers/booking_price_providers.dart';
import '../../features/reservations/providers/reservation_providers.dart';
import '../../features/workspace/domain/member.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../../features/workspace/providers/kpi_providers.dart';
import '../../features/workspace/providers/workspace_fields_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../features/workspace/providers/workspace_roles_providers.dart';
import '../storage/resume_place_store.dart';
import 'data/bank_statement_repository.dart';
import 'data/demo_booking_prices.dart';
import 'data/finance_kpi_repository.dart';
import 'data/money/demo_credit_moves.dart';
import 'data/money/demo_settlement_reviews.dart';
import 'data/money_repository.dart';
import 'data/my_reservations_repository.dart';
import 'data/series_previewer.dart';
import 'data/workspace_repository.dart' show FakeWorkspaceMembership;
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
  final myReservations = _myReservations(fixture);
  // #3865 — each space's last bank statement lives on the fixture.
  final banks = demoMapSpaces(fixture.stores, (s) => s.bank);
  return [
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
    financeHostsFromMe,
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
    ..._moneyPortOverrides(money),
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
    recordedPaymentsRepositoryProvider.overrideWith(
      (ref) => demoPickSpace(ref, payments),
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

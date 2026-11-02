// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The repositories that hold ONE space's rows, answered per space.
//
// The demo has two spaces (Pézenas and Leipzig, `demo_second_space.dart`),
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
    show myReservationsSourcesFromMe;
import '../../features/money/domain/hmrc_submission.dart';
import '../../features/money/providers/bank_statement_providers.dart';
import '../../features/money/providers/credit_providers.dart';
import '../../features/money/providers/hmrc_providers.dart';
import '../../features/money/providers/money_providers.dart';
import '../../features/money/providers/recorded_payments_providers.dart';
import '../../features/plan/providers/accessory_providers.dart';
import '../../features/plan/providers/charging_station_providers.dart';
import '../../features/plan/providers/floor_plan_providers.dart';
import '../../features/reservations/providers/reservation_providers.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../../features/workspace/providers/kpi_providers.dart';
import '../../features/workspace/providers/workspace_fields_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../features/workspace/providers/workspace_roles_providers.dart';
import '../storage/resume_place_store.dart';
import 'data/bank_statement_repository.dart';
import 'data/finance_kpi_repository.dart';
import 'data/money_repository.dart';
import 'data/my_reservations_repository.dart';
import 'data/plan_resource_repository.dart';
import 'data/series_previewer.dart';
import 'demo_fixture.dart';
import 'seed/demo_london_seed.dart';
import 'seed/demo_second_space_seed.dart';

/// Demo's one fictional installation: nothing is verified against a
/// server, and every client borrows the fakes (#1625).
const kDemoInstallationId = '00000000-0000-4000-8000-00000000de30';

/// Which of the demo's three spaces the scope is looking at. An id no space
/// owns fails closed: it never borrows another space's data.
enum _Space { home, leipzig, london }

_Space _space(Ref ref) {
  final id = ref.watch(currentWorkspaceProvider).value?.id;
  return switch (id) {
    null || '' || demoFirstSpaceId => _Space.home,
    demoSecondSpaceId => _Space.leipzig,
    demoLondonSpaceId => _Space.london,
    _ => throw StateError('unknown demo space: $id'),
  };
}

/// #2553 — the two spaces as the own-reservations read sees them: one
/// installation, read the way a workspace host answers. A space's name is
/// looked up when a page is built, and a space the session no longer lists
/// is named by its id rather than refused.
DemoMyReservationsRepository _myReservations(DemoFixture fixture) =>
    DemoMyReservationsRepository(
      installationId: kDemoInstallationId,
      spaces: [
        (floorPlan: fixture.floorPlan, reservations: fixture.reservations),
        (
          floorPlan: fixture.secondSpace.floorPlan,
          reservations: fixture.secondSpace.reservations,
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

/// The per-space overrides of a Demo scope over [fixture].
List<Override> demoSpaceOverrides(DemoFixture fixture) {
  final home = fixture;
  final second = fixture.secondSpace;
  final london = fixture.london;
  T pick<T>(Ref ref, T main, T leipzig, T london) => switch (_space(ref)) {
    _Space.home => main,
    _Space.leipzig => leipzig,
    _Space.london => london,
  };
  final homeResources = FakePlanResourceRepository(home.floorPlan);
  final homeActions = FakeInvoiceActionCommands(home.money);
  final secondActions = FakeInvoiceActionCommands(second.money);
  final londonActions = FakeInvoiceActionCommands(london.money);
  FakeMoneyRepository money(Ref ref) =>
      pick(ref, home.money, second.money, london.money);
  DemoFinanceKpiRepository kpi(FakeMoneyRepository m) =>
      DemoFinanceKpiRepository(
        money: m,
        workspaces: home.workspaces,
        now: home.seededAt,
      );
  final homeKpi = kpi(home.money);
  final myReservations = _myReservations(fixture);
  final secondKpi = kpi(second.money);
  final londonKpi = kpi(london.money);
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
  final homeBank = seedDemoBankStatements(home.money, home.seededAt);
  final secondBank = FakeBankStatementRepository(
    money: second.money,
    today: home.seededAt,
  );
  final londonBank = FakeBankStatementRepository(
    money: london.money,
    today: home.seededAt,
  );
  return [
    workspaceRepositoryProvider.overrideWith(
      (ref) => pick(ref, home.workspaces, second.workspaces, london.workspaces),
    ),
    floorPlanRepositoryProvider.overrideWith(
      (ref) => pick(ref, home.floorPlan, second.floorPlan, london.floorPlan),
    ),
    // #2631 — rooms, parking areas and chargers live in memory.
    planResourceRepositoryProvider.overrideWith(
      (ref) => pick(ref, homeResources, second.planResources, london.planResources),
    ),
    chargingStationRepositoryProvider.overrideWith(
      (ref) => pick(ref, home.chargingStations, second.chargingStations, london.chargingStations),
    ),
    reservationRepositoryProvider.overrideWith(
      (ref) => pick(ref, home.reservations, second.reservations, london.reservations),
    ),
    // #2553 — the visitor's own bookings of both spaces, one installation.
    myReservationsRepositoryProvider.overrideWithValue(myReservations),
    // Where the visitor was last stays inside the demonstration.
    resumePlaceStoreProvider.overrideWithValue(fixture.prefs.resumePlaces),
    // #2553 C3 — View, Check in and Cancel on the fixture's own spaces.
    myReservationActionsProvider.overrideWithValue(
      DemoMyReservationActions(myReservations),
    ),
    // #2553 C2 — read for every space the persona's personal home names.
    myReservationsSourcesFromMe,
    // #2557 C5 — Me › Finances reads the same hosts; the fixture's spaces
    // are the personal home's own, answered by its own read.
    financeHostsFromMe,
    // #2552 XPRIV-01 — the persona's mask choice, as the app reads it.
    privateValuesFromAccount,
    // #2575
    seriesPreviewerProvider.overrideWith(
      (ref) => FakeSeriesPreviewer(
        pick(ref, home.reservations, second.reservations, london.reservations),
      ),
    ),
    eventRepositoryProvider.overrideWith(
      (ref) => pick(ref, home.events, second.events, london.events),
    ),
    calendarRepositoryProvider.overrideWith(
      (ref) => pick(ref, home.calendar, second.calendar, london.calendar),
    ),
    // #2591 — each money port has its own demo adapter over the space's
    // one in-memory store; the facade stays for the tests that read it.
    moneyRepositoryProvider.overrideWith(money),
    // #2380 — the main space's last bank statement; the second has none yet.
    bankStatementRepositoryProvider.overrideWith(
      (ref) => pick(ref, homeBank, secondBank, londonBank),
    ),
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
    memberAccountQueriesProvider.overrideWith(
      (ref) => money(ref).accountQueries,
    ),
    memberAccountCommandsProvider.overrideWith(
      (ref) => money(ref).accountCommands,
    ),
    reportTemplateRepositoryProvider.overrideWith(
      (ref) => money(ref).reportTemplates,
    ),
    invoiceCommandsProvider.overrideWith((ref) => money(ref).invoiceCommands),
    // #2585
    invoiceActionCommandsProvider.overrideWith(
      (ref) => pick(ref, homeActions, secondActions, londonActions),
    ),
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
    eInvoiceTransmissionsProvider.overrideWith((ref) => money(ref).eInvoices),
    // #2365
    accountingSourceQueriesProvider.overrideWith(
      (ref) => money(ref).accountingSource,
    ),
    creditRepositoryProvider.overrideWith(
      (ref) => pick(ref, home.credits, second.credits, london.credits),
    ),
    accessoryRepositoryProvider.overrideWith(
      (ref) => pick(ref, home.accessories, second.accessories, london.accessories),
    ),
    workspaceFieldsRepositoryProvider.overrideWith(
      (ref) => pick(ref, home.fields, second.fields, london.fields),
    ),
    workspaceRolesRepositoryProvider.overrideWith(
      (ref) => pick(ref, home.roles, second.roles, london.roles),
    ),
    // #1924 — the finance cards sum the space's own invoices and matches,
    // with the server's predicates.
    financeKpiRepositoryProvider.overrideWith(
      (ref) => pick(ref, homeKpi, secondKpi, londonKpi),
    ),
    // #2470 — the HMRC port is the Demo's: nothing leaves the process.
    hmrcRepositoryProvider.overrideWith((ref) => london.hmrc),
    // The Demo sends nothing, so the browser's fraud-prevention values are
    // synthetic too: the journey is the same on every build.
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
    // #2578 — the payments behind the collected figure, from the same
    // matches the finance cards sum.
    recordedPaymentsRepositoryProvider.overrideWith(
      (ref) => pick(ref, homePayments, secondPayments, londonPayments),
    ),
  ];
}

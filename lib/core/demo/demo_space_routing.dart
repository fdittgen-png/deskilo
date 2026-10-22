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

import '../../features/calendar/providers/calendar_providers.dart';
import '../../features/events/providers/event_providers.dart';
import '../../features/money/providers/credit_providers.dart';
import '../../features/money/providers/money_providers.dart';
import '../../features/plan/providers/accessory_providers.dart';
import '../../features/plan/providers/charging_station_providers.dart';
import '../../features/plan/providers/floor_plan_providers.dart';
import '../../features/reservations/providers/reservation_providers.dart';
import '../../features/workspace/providers/kpi_providers.dart';
import '../../features/workspace/providers/workspace_fields_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../features/workspace/providers/workspace_roles_providers.dart';
import 'data/finance_kpi_repository.dart';
import 'data/money_repository.dart';
import 'data/plan_resource_repository.dart';
import 'data/series_previewer.dart';
import 'demo_fixture.dart';
import 'seed/demo_second_space_seed.dart';

/// Whether the scope is looking at the Leipzig space.
bool _leipzig(Ref ref) =>
    ref.watch(currentWorkspaceProvider).value?.id == demoSecondSpaceId;

/// The per-space overrides of a Demo scope over [fixture].
List<Override> demoSpaceOverrides(DemoFixture fixture) {
  final home = fixture;
  final second = fixture.secondSpace;
  T pick<T>(Ref ref, T main, T leipzig) => _leipzig(ref) ? leipzig : main;
  final homeResources = FakePlanResourceRepository(home.floorPlan);
  final homeActions = FakeInvoiceActionCommands(home.money);
  final secondActions = FakeInvoiceActionCommands(second.money);
  FakeMoneyRepository money(Ref ref) => pick(ref, home.money, second.money);
  DemoFinanceKpiRepository kpi(FakeMoneyRepository m) =>
      DemoFinanceKpiRepository(
        money: m,
        workspaces: home.workspaces,
        now: home.seededAt,
      );
  final homeKpi = kpi(home.money);
  final secondKpi = kpi(second.money);
  return [
    workspaceRepositoryProvider.overrideWith(
      (ref) => pick(ref, home.workspaces, second.workspaces),
    ),
    floorPlanRepositoryProvider.overrideWith(
      (ref) => pick(ref, home.floorPlan, second.floorPlan),
    ),
    // #2631 — rooms, parking areas and chargers live in memory.
    planResourceRepositoryProvider.overrideWith(
      (ref) => pick(ref, homeResources, second.planResources),
    ),
    chargingStationRepositoryProvider.overrideWith(
      (ref) => pick(ref, home.chargingStations, second.chargingStations),
    ),
    reservationRepositoryProvider.overrideWith(
      (ref) => pick(ref, home.reservations, second.reservations),
    ),
    // #2575
    seriesPreviewerProvider.overrideWith(
      (ref) => FakeSeriesPreviewer(
        pick(ref, home.reservations, second.reservations),
      ),
    ),
    eventRepositoryProvider.overrideWith(
      (ref) => pick(ref, home.events, second.events),
    ),
    calendarRepositoryProvider.overrideWith(
      (ref) => pick(ref, home.calendar, second.calendar),
    ),
    // #2591 — the money interfaces, all one in-memory repository a space.
    moneyRepositoryProvider.overrideWith(money),
    invoiceQueriesProvider.overrideWith(money),
    memberAccountQueriesProvider.overrideWith(money),
    reportTemplateRepositoryProvider.overrideWith(money),
    invoiceCommandsProvider.overrideWith(money),
    // #2585
    invoiceActionCommandsProvider.overrideWith(
      (ref) => pick(ref, homeActions, secondActions),
    ),
    taxReportingRepositoryProvider.overrideWith(money),
    commercialTermsProvider.overrideWith(money),
    expenseRepositoryProvider.overrideWith(money),
    // #2365
    accountingSourceQueriesProvider.overrideWith(money),
    creditRepositoryProvider.overrideWith(
      (ref) => pick(ref, home.credits, second.credits),
    ),
    accessoryRepositoryProvider.overrideWith(
      (ref) => pick(ref, home.accessories, second.accessories),
    ),
    workspaceFieldsRepositoryProvider.overrideWith(
      (ref) => pick(ref, home.fields, second.fields),
    ),
    workspaceRolesRepositoryProvider.overrideWith(
      (ref) => pick(ref, home.roles, second.roles),
    ),
    // #1924 — the finance cards sum the space's own invoices and matches,
    // with the server's predicates.
    financeKpiRepositoryProvider.overrideWith(
      (ref) => pick(ref, homeKpi, secondKpi),
    ),
  ];
}

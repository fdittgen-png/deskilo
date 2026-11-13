// SPDX-License-Identifier: AGPL-3.0-or-later
// Zurich and Milan each keep one graph: what the purchasing, sales and setup
// screens read is the same data, with a deterministic clock and local terms.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import '../../features/plan/domain/seat.dart';
import '../../features/workspace/domain/workspace.dart';
import 'data/accessory_repository.dart';
import 'data/book_profile_repository.dart';
import 'data/booking_right_reservations.dart';
import 'data/calendar_repository.dart';
import 'data/city_floor_plan_repository.dart';
import 'data/credit_repository.dart';
import 'data/decision_effects.dart';
import 'data/event_repository.dart';
import 'data/event_visibility.dart';
import 'data/floor_plan_repository.dart';
import 'data/money/demo_member_statement.dart';
import 'data/money_repository.dart';
import 'data/plan_resource_repository.dart';
import 'data/premises_lease_repository.dart';
import 'data/room_rental_repository.dart';
import 'data/workspace_fields_repository.dart';
import 'data/workspace_repository.dart';
import 'data/workspace_roles_repository.dart';
import 'seed/demo_calendar_seed.dart';
import 'seed/demo_city_books_seed.dart';
import 'seed/demo_city_money_seed.dart';
import 'seed/demo_city_plan_seed.dart';
import 'seed/demo_city_purchase_seed.dart';
import 'seed/demo_city_usage_seed.dart';
import 'seed/demo_city_workflow_seed.dart';
import 'seed/demo_commerce_country_seed.dart';
import 'seed/demo_commerce_fx_seed.dart';
import 'seed/demo_purchase_seed.dart';

class DemoCommerceSpaceData {
  DemoCommerceSpaceData._({required this.spec, required this.workspaces,
    required this.floorPlan, required this.reservations, required this.events,
    required this.calendar, required this.money, required this.purchasing,
    required this.books, required this.seededAt});

  factory DemoCommerceSpaceData.build({
    required DemoCommerceSpec spec,
    required FakeWorkspaceRepository home,
    required String Function() actor,
    required DateTime now,
  }) {
    final space = FakeWorkspaceRepository(workspaces: home.workspaces);
    home.workspaces.add(demoCommerceWorkspace(spec));
    seedCommercePeople(space, spec);
    final plan = CityFloorPlanRepository();
    seedCityPlans(plan, workspaceId: spec.workspaceId, prefix: spec.prefix,
      sites: [spec.siteId], mainFloorOffices: [2]);
    final reservations = RightsCheckedReservationRepository(actor: actor);
    reservations.resourceSeatIds.addAll(plan.seats
      .where((s) => s.resourceKind != ResourceKind.seat).map((s) => s.id));
    final events = FakeEventRepository(actor: actor, workspaceId: spec.workspaceId,
      clock: () => now, decider: () => space.memberOf(actor()));
    seedCityDecisions(events, spec.prefix, now);
    final money = FakeMoneyRepository(events: events, clock: () => now)
      ..invoiceCommands.currency = spec.currency
      ..vatRates = [VatRate(id: '${spec.prefix}-vat-standard', label: 'Standard',
        percent: spec.vatPercent, isDefault: true)];
    seedCityExpenses(money, spec.workspaceId, spec.prefix, now);
    seedCityMoney(money, space, (
      workspaceId: spec.workspaceId, prefix: spec.prefix, name: spec.name,
      currency: spec.currency, now: now, years: 1, vatPercent: spec.vatPercent,
      siteRentals: const [], hourlyBookings: const [],
    ), subscriptionLabel: 'Monthly service contract', invoiceTitle: 'Services and supplies',
      catalogue: demoCommerceCatalogue);
    seedCityUsage(money, reservations.reservations);
    final calendar = FakeCalendarRepository(actor: actor);
    seedDemoCalendar(calendar, reservations: reservations, money: money,
      events: events, currency: spec.currency);
    wireDecisionEffects(events, reservations: reservations, workspaces: space,
      money: money, now: () => now);
    final purchasing = cityPurchasing(now, spec: (workspaceId: spec.workspaceId,
      prefix: spec.prefix, country: spec.country, currency: spec.currency,
      years: 1, vatPercent: spec.vatPercent), actor: actor, siteIds: [spec.siteId],
      labels: demoCommercePurchaseLabels);
    seedCommerceForeignBill(purchasing, spec, now);
    final city = DemoCommerceSpaceData._(spec: spec, workspaces: space,
      floorPlan: plan, reservations: reservations, events: events,
      calendar: calendar, money: money, purchasing: purchasing, seededAt: now,
      books: cityBooks(money, now, spec: (workspaceId: spec.workspaceId,
        siteId: spec.siteId, country: spec.country, currency: spec.currency),
        external: false, purchases: purchasing.purchases));
    seedCityPeopleWorkflows((space: space, fields: city.fields, roles: city.roles,
      credits: city.credits, workspaceId: spec.workspaceId, prefix: spec.prefix,
      now: now));
    city.accessories.seedSmallCatalog(workspaceId: spec.workspaceId);
    seedCityCharger(city.chargingStations, spec.prefix);
    events.viewerPermissions = demoViewerPermissions(space, city.roles,
      spec.workspaceId, actor);
    money.accountQueries.statementSource = demoStatementSource(space,
      reservations, spec.workspaceId, actor: actor, credits: city.credits);
    return city;
  }

  final DemoCommerceSpec spec;
  final DateTime seededAt;
  late final assets = cityAssets(seededAt, prefix: spec.prefix,
    currency: spec.currency, years: 1, vatPercent: spec.vatPercent, sites: [spec.siteId]);
  final lease = FakePremisesLeaseRepository();
  late final rooms = FakeRoomRentalRepository(currency: spec.currency);
  late final accounting = cityAccounting(seededAt, sage: false);
  late final periods = accounting.books;
  final FakeWorkspaceRepository workspaces;
  final FakeFloorPlanRepository floorPlan;
  final RightsCheckedReservationRepository reservations;
  final FakeEventRepository events;
  final FakeCalendarRepository calendar;
  final FakeMoneyRepository money;
  final DemoPurchasing purchasing;
  final FakeBookProfileRepository books;
  final credits = FakeCreditRepository();
  final accessories = FakeAccessoryRepository();
  final chargingStations = FakeChargingStationRepository();
  final fields = FakeWorkspaceFields();
  final roles = FakeWorkspaceRoles();
  late final planResources = FakePlanResourceRepository(floorPlan);
  Workspace? _parked;

  void viewAs(String memberId, FakeWorkspaceRepository home) {
    final rows = [workspaces.myMember, ...workspaces.otherMembers];
    final mine = rows.where((m) => m.id == memberId).firstOrNull;
    home.extraMyMemberships.removeWhere((m) => m.workspaceId == spec.workspaceId);
    final listed = home.workspaces.indexWhere((w) => w.id == spec.workspaceId);
    if (mine == null) {
      if (listed >= 0) _parked = home.workspaces.removeAt(listed);
      return;
    }
    workspaces.myMember = mine;
    workspaces.otherMembers..clear()..addAll(rows.where((m) => m.id != mine.id));
    home.extraMyMemberships.add(mine);
    if (listed < 0 && _parked != null) home.workspaces.add(_parked!);
    _parked = null;
  }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
// Fictional per-workspace starting points for the city's everyday workflows.
import '../../../features/events/domain/validation_policy.dart';
import '../../../features/events/domain/workspace_event.dart';
import '../../../features/money/domain/expense_schedule.dart';
import '../../../features/plan/domain/charging_station.dart';
import '../../../features/workspace/domain/member_badge.dart';
import '../../../features/workspace/domain/workspace_document.dart';
import '../data/credit_repository.dart';
import '../data/event_repository.dart';
import '../data/money_repository.dart';
import '../data/plan_resource_repository.dart';
import '../data/workspace_fields_repository.dart';
import '../data/workspace_repository.dart';
import '../data/workspace_roles_repository.dart';
import 'demo_commerce_seed.dart';
import 'demo_people_seed.dart';

void seedCityExpenses(
  FakeMoneyRepository money,
  String workspaceId,
  String prefix,
  DateTime now,
) {
  final due = DateTime(now.year, now.month);
  final schedule = '$prefix-internet-schedule';
  money.expenseSchedules.add(
    ExpenseSchedule(
      id: schedule,
      workspaceId: workspaceId,
      memberId: 'member-3',
      title: 'Internet service',
      amountCents: 18000,
      startsOn: DateTime(now.year - 1, now.month),
      unit: ScheduleUnit.month,
      status: ScheduleStatus.active,
      occurrencesDone: 12,
      nextDue: due,
    ),
  );
  money.expenseOccurrences.add(
    ExpenseOccurrence(
      id: '$prefix-internet-occurrence',
      scheduleId: schedule,
      workspaceId: workspaceId,
      memberId: 'member-3',
      dueOn: due,
      amountCents: 18000,
      scheduleTitle: 'Internet service',
      scheduledAmountCents: 18000,
    ),
  );
}

void seedCityCharger(FakeChargingStationRepository chargers, String prefix) {
  final seat = '$prefix-parking-1';
  chargers.stations[seat] = ChargingStation(
    id: '$prefix-charger',
    seatId: seat,
    name: 'Demo EV charger',
    connector: ChargerConnector.type2,
    powerKw: 22,
  );
}

void seedCityPeopleWorkflows(
  ({
    FakeWorkspaceRepository space,
    FakeWorkspaceFields fields,
    FakeWorkspaceRoles roles,
    FakeCreditRepository credits,
    String workspaceId,
    String prefix,
    DateTime now,
  })
  city,
) {
  final (:space, :fields, :roles, :credits, :workspaceId, :prefix, :now) = city;
  seedDemoFields(fields);
  seedDemoRoles(roles);
  // The original fixture's accountant is not a member of these cities.
  roles.assignments['demo-role-accountant'] = ['member-3'];
  seedDemoCarnets(credits);
  space.badges.addAll([
    MemberBadge(
      id: '$prefix-badge-owner',
      workspaceId: workspaceId,
      memberId: 'member-1',
      label: 'Ada · QR',
      createdAt: now,
      authEnabled: true,
    ),
    MemberBadge(
      id: '$prefix-badge-member',
      workspaceId: workspaceId,
      memberId: 'member-2',
      label: 'Bruno · card',
      createdAt: now,
      kind: BadgeKind.nfc,
    ),
  ]);
  space.documents.addAll([
    WorkspaceDocument(
      id: '$prefix-rules',
      workspaceId: workspaceId,
      title: 'House rules',
      category: 'statutes',
      url: 'https://example.test/$prefix/house-rules.pdf',
    ),
    WorkspaceDocument(
      id: '$prefix-guide',
      workspaceId: workspaceId,
      title: 'Printing and workspace guide',
      category: 'guides',
      url: 'https://example.test/$prefix/guide.pdf',
    ),
  ]);
}

void seedCityDecisions(
  FakeEventRepository events,
  String prefix,
  DateTime now,
) {
  for (final (name, type, payload) in [
    ('quota', EventType.quota, <String, Object>{'half_days': 2}),
    (
      'expense',
      EventType.expense,
      <String, Object>{
        'amount_cents': 2450,
        'supply': {'name': 'Printer paper', 'quantity': 5},
      },
    ),
    (
      'service',
      EventType.serviceCharge,
      <String, Object>{'name': 'Coffee', 'quantity': 4, 'price_cents': 250},
    ),
  ]) {
    events.events.add(
      WorkspaceEvent(
        id: '$prefix-$name',
        workspaceId: events.workspaceId,
        type: type,
        action: EventAction.submitted,
        actorMemberId: 'member-2',
        subjectMemberId: 'member-2',
        payload: payload,
        status: EventStatus.pending,
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
    );
    events.policies.add(
      ValidationPolicy(
        id: '$prefix-policy-$name',
        workspaceId: events.workspaceId,
        eventType: type.dbName,
        requiredCount: 1,
        adminsMayValidate: true,
        eligibleAdminIds: const [],
        ownerRequired: false,
      ),
    );
  }
}

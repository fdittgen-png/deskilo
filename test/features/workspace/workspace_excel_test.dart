// SPDX-License-Identifier: 0BSD
//
// The Excel data export (#395): the workbook builder is pure — seed the
// domain objects, assert the tabs and the rows. Headers are STABLE
// ENGLISH identifiers by design (the XML-schema decision, not the bill
// PDF's): they get referenced by formulas and importers, so they must
// not rename themselves with the phone's language.

import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/payment_intent.dart';
import 'package:deskilo/features/workspace/domain/workspace_excel.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';

void main() {
  test('the workbook carries all eleven tabs with their headers and the '
      'seeded records land on the right ones', () async {
    final workspaceRepo = FakeWorkspaceRepository.withWorkspace();
    final workspace = workspaceRepo.workspaces.single;
    final plans = FakeFloorPlanRepository()..seedSmallPlan();
    final levels = await plans.fetchLevels('ws-1');
    final plan = await plans.fetchPlan(levels.first.id);
    final start = DateTime(kTestNow.year, kTestNow.month, kTestNow.day, 9);

    final sheets = buildWorkspaceExcelExport(
      workspace: workspace,
      enabledFeatures: const {'moneyTab', 'dataExport'},
      levels: levels,
      plansByLevel: {levels.first.id: plan},
      members: [workspaceRepo.myMember],
      profilesByUserId: const {},
      reservations: [
        Reservation(
          id: 'res-1',
          workspaceId: 'ws-1',
          seatId: plan.seats.first.id,
          memberId: 'member-1',
          startsAt: start,
          endsAt: start.add(const Duration(hours: 4)),
          status: ReservationStatus.completed,
          checkedInAt: start,
          checkedOutAt: start.add(const Duration(hours: 4)),
        ),
      ],
      ledger: [
        LedgerEntry(
          id: 'led-1',
          memberId: 'member-1',
          kind: LedgerKind.credit,
          category: LedgerCategory.payment,
          amountCents: 4250,
          description: 'bank transfer',
          period: kTestPeriod,
          createdAt: kTestNow,
        ),
      ],
      pendingEvents: const [],
      paymentIntents: [
        PaymentIntent(
          id: 'pi-1',
          memberId: 'member-1',
          provider: 'paypal',
          orderId: 'ORDER-1',
          period: kTestPeriod,
          amountCents: 1000,
          status: 'captured',
          createdAt: kTestNow,
        ),
      ],
      services: const [],
      invoices: const [],
      transmissionsByInvoice: const {},
    );

    expect(sheets.map((s) => s.name).toList(), [
      'Workspace', 'Levels', 'Desks', 'Seats', 'Users', 'Reservations',
      'Check-ins', 'Payments', 'Services', 'Service catalog', 'Invoices',
    ]);

    Map<String, Object?> row(String tab, int index) {
      final sheet = sheets.singleWhere((s) => s.name == tab);
      return Map.fromIterables(
        sheet.rows.first.cast<String>(),
        sheet.rows[index],
      );
    }

    // The attended reservation appears on BOTH booking tabs, resolved to
    // the seat's name, with the presence duration derived.
    expect(row('Reservations', 1)['space'], plan.seats.first.name);
    expect(row('Check-ins', 1)['minutes_present'], 240);

    // Money in MAJOR units so a column sums without scale-guessing.
    expect(row('Payments', 1)['state'], 'confirmed');
    expect(row('Payments', 1)['amount'], 42.5);
    expect(row('Payments', 2)['state'], 'online (captured)');
    expect(row('Payments', 2)['provider'], 'paypal');

    // The workspace row names its enabled features.
    expect(row('Workspace', 1)['enabled_features'], 'dataExport, moneyTab');
  });
}

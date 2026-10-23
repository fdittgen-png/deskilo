// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Excel data export (#395): the workbook builder is pure — seed the
// domain objects, assert the tabs and the rows. Headers are STABLE
// ENGLISH identifiers by design (the XML-schema decision, not the bill
// PDF's): they get referenced by formulas and importers, so they must
// not rename themselves with the phone's language.

import 'package:deskilo/core/files/xlsx.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/payment_intent.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/workspace_excel.dart';
import 'package:deskilo/features/workspace/domain/workspace_export_sources.dart';
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

    final ledger = [
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
      // A subscription charge: the first workbook never wrote charges;
      // the Ledger tab (#2860) carries every row.
      LedgerEntry(
        id: 'led-2',
        memberId: 'member-1',
        kind: LedgerKind.charge,
        category: LedgerCategory.subscription,
        amountCents: 20000,
        description: 'subscription',
        period: kTestPeriod,
        createdAt: kTestNow,
      ),
    ];
    final base = buildWorkspaceExcelExport(
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
      ledger: ledger,
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
    final sheets = [
      ...base,
      ...buildWorkspaceExcelDetailSheets(WorkspaceExportDetails(
        workspace: workspace,
        levels: levels,
        plansByLevel: {levels.first.id: plan},
        memberName: const {'member-1': 'Me'},
        ledger: ledger,
        events: const [],
        decisions: const {},
        invoices: const [],
      )),
    ];

    expect(sheets.map((s) => s.name).toList(), [
      'Overview', 'Features', 'Levels', 'Desks', 'Seats', 'Users', 'Reservations',
      'Check-ins', 'Payments', 'Services', 'Service catalog', 'Invoices',
      'Offices', 'Ledger', 'Events', 'Decisions', 'Invoice lines',
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
    expect((row('Payments', 1)['amount']! as XlsxAmount).value, 42.5);
    expect(row('Payments', 2)['state'], 'online (captured)');
    expect(row('Payments', 2)['provider'], 'paypal');

    // #2861 — the workspace is an Overview of fields, and every feature is
    // a row of the Features sheet, by process, with whether it is on.
    expect(row('Overview', 1), {'field': 'name', 'value': workspace.name});
    final features = sheets.singleWhere((s) => s.name == 'Features').rows;
    expect(
      features.where((r) => r[1] == 'moneyTab').single,
      ['billingPayments', 'moneyTab', true],
    );
    expect(features.where((r) => r[1] == 'invoicing').single[2], isFalse);

    // #2859 — a source the workbook declares whole writes every row it
    // was given; dropping rows from the builder fails here, not silently.
    int rowsOf(String tab, [bool Function(List<Object?> row)? where]) =>
        sheets
            .singleWhere((s) => s.name == tab)
            .rows
            .skip(1)
            .where(where ?? (_) => true)
            .length;
    final written = <String, (int, int)>{
      'workspaces': (rowsOf('Overview'), 12),
      'levels': (rowsOf('Levels'), levels.length),
      'desks': (rowsOf('Desks'), plan.desks.length),
      'seats': (rowsOf('Seats'), plan.seats.length),
      'members': (rowsOf('Users'), 1),
      'reservations': (rowsOf('Reservations'), 1),
      'payment_intents':
          (rowsOf('Payments', (r) => '${r.first}'.startsWith('online')), 1),
      'ledger_entries': (rowsOf('Ledger'), ledger.length),
      'offices': (rowsOf('Offices'), plan.offices.length),
      'events': (rowsOf('Events'), 0),
      'event_decisions': (rowsOf('Decisions'), 0),
      'invoice_maturities': (rowsOf('Invoices'), 0),
      'services': (rowsOf('Service catalog'), 0),
      'invoices': (rowsOf('Invoices'), 0),
    };
    for (final source in workspaceExportSources) {
      // A table the server writes whole has no model-built sheet here.
      if (source.partial != null || source.everyColumn) continue;
      expect(written, contains(source.table),
          reason: '${source.table} is declared whole: count its rows here');
      final (actual, given) = written[source.table]!;
      expect(actual, given, reason: '${source.table} lost rows');
    }

    // The signed amounts of one member's ledger sum to their balance:
    // 200.00 owed, 42.50 paid.
    final signed = sheets
        .singleWhere((s) => s.name == 'Ledger')
        .rows
        .skip(1)
        .map((r) => (r[5]! as XlsxAmount).value)
        .fold(0.0, (a, b) => a + b);
    expect(signed, 157.5);
  });
}

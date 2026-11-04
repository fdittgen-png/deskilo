// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 3 — the sales figures: read from `kpi_sales_quality` (0674),
// exact to the minor unit, a missing amount never 0; sales net of VAT by
// kind of line and by service, credits left out, a credit note
// subtracting; the margin of the rented rooms, null while the space rents
// none. The Demo computes the same sales from pgTAP 354's month.
import 'package:deskilo/core/demo/data/room_rental_repository.dart';
import 'package:deskilo/core/demo/data/sales_kpi_repository.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/room_rental.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/bi_modules.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/domain/kpi_sales.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/presentation/widgets/bi_module_section.dart';
import 'package:deskilo/features/workspace/providers/bi_sales_reader.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

const _ids = [
  'sales.revenue_by_kind',
  'sales.revenue_by_service',
  'sales.room_margin',
];

/// What pgTAP 354 reads for the owner, March 2025.
Map<String, Object?> _row({
  bool mixed = false,
  bool rooms = true,
  Object? net = '23500',
  int netUnknown = 0,
}) {
  String? a(String v) => mixed ? null : v;
  return {
    'from': '2025-03',
    'to': '2025-03',
    'currency': 'EUR',
    'revenue': {
      'invoices': 4,
      'lines': mixed ? 8 : 7,
      'net_unknown_lines': netUnknown,
      'net_minor': mixed ? null : net,
      'gross_minor': a('28100'),
      'kinds': [
        {
          'kind': 'package',
          'lines': 1,
          'net_minor': a('10000'),
          'gross_minor': a('12000'),
        },
        {
          'kind': 'subscription',
          'lines': 2,
          'net_minor': a('9000'),
          'gross_minor': a('10800'),
        },
        {
          'kind': 'service',
          'lines': 3,
          'net_minor': a('2500'),
          'gross_minor': a('2900'),
        },
        {
          'kind': 'overage',
          'lines': 1,
          'net_minor': a('2000'),
          'gross_minor': a('2400'),
        },
      ],
      'months': [
        {
          'month': '2025-03',
          'net_minor': a('23500'),
          'gross_minor': a('28100'),
        },
      ],
    },
    'services': {
      'services': 3,
      'net_minor': a('12500'),
      'rows': [
        {
          'rank': 1,
          'name': 'Ten half-days',
          'kind': 'package',
          'lines': 1,
          'net_minor': a('10000'),
          'gross_minor': a('12000'),
        },
        {
          'rank': 2,
          'name': 'Coffee',
          'kind': 'service',
          'lines': 2,
          'net_minor': a('1500'),
          'gross_minor': a('1800'),
        },
        {
          'rank': 3,
          'name': 'Printing',
          'kind': 'service',
          'lines': 1,
          'net_minor': a('1000'),
          'gross_minor': a('1100'),
        },
      ],
    },
    'rooms': rooms
        ? {
            'rooms': 2,
            'uses': 5,
            'charges_minor': a('53000'),
            'cost_minor': a('34000'),
            'margin_minor': a('19000'),
            'rows': [
              {
                'office_id': 'o1',
                'name': 'Studio',
                'cost_kind': 'fixed_per_period',
                'uses': 3,
                'charges_minor': a('45000'),
                'cost_minor': a('30000'),
                'margin_minor': a('15000'),
              },
              {
                'office_id': 'o2',
                'name': 'Loft',
                'cost_kind': 'per_use',
                'uses': 2,
                'charges_minor': a('8000'),
                'cost_minor': a('4000'),
                'margin_minor': a('4000'),
              },
            ],
          }
        : null,
    'quality': [if (mixed) 'unavailable'],
    'reasons': [if (mixed) 'currency_mix', if (!rooms) 'external_rooms_off'],
    'computed_at': '2026-11-04T12:00:00Z',
  };
}

InvoiceLine _line(
  String kind,
  int cents, {
  String label = '',
  double vat = 20,
  int? net,
}) => InvoiceLine(
  kind: kind,
  label: label,
  amountCents: cents,
  vatPercent: vat,
  netCents: net,
);

Invoice _invoice(
  String id,
  List<InvoiceLine> lines, {
  String period = '2025-03',
  String currency = 'EUR',
  bool voided = false,
}) => Invoice(
  id: id,
  workspaceId: 'ws-1',
  memberId: 'member-2',
  number: 'S-$id',
  issuedAt: DateTime.parse('$period-05'),
  period: period,
  title: 'T',
  lines: lines,
  totalCents: lines.fold(0, (s, l) => s + l.amountCents),
  currency: currency,
  memberName: 'Name',
  memberAddress: '',
  workspaceName: 'Sales',
  workspaceAddress: '',
  issuerName: 'Owner',
  signature: 's',
  kind: InvoiceKind.usage,
  voidedAt: voided ? DateTime(2025, 3, 6) : null,
);

/// pgTAP 354's March invoices in the Demo's own records.
List<Invoice> _march() => [
  _invoice('d1', [
    _line('subscription', 12000, label: '100'),
    _line('service', 600, label: 'Coffee'),
    _line('payment', -5000, vat: 0),
  ]),
  _invoice('d2', [
    _line('overage', 2400),
    _line('package', 12000, label: 'Ten half-days'),
    _line('service', 1200, label: 'Coffee'),
  ]),
  _invoice('d3', [
    _line('service', 1100, label: 'Printing', vat: 0, net: 1000),
  ]),
  _invoice('e1', [_line('subscription', -1200, label: '100')]),
  _invoice('d4', [_line('subscription', 9999, label: '100')], voided: true),
  _invoice('d5', [
    _line('subscription', 5000, label: '100'),
  ], period: '2025-04'),
];

void main() {
  final l10n = AppLocalizationsEn();

  group('the contract', () {
    test('the three cards need the status, the finance right, and the room '
        'margin rented rooms', () {
      final modules = {for (final m in biModules) m.id: m};
      for (final id in _ids) {
        expect(
          modules[id]?.feature,
          WorkspaceFeature.workspaceStatus,
          reason: id,
        );
        expect(kpiDefinitionOf(id), isNotNull, reason: id);
        expect(biModuleViews[id], isNotNull, reason: id);
      }
      const finance = {
        WorkspacePermission.viewAnalytics,
        WorkspacePermission.viewFinances,
      };
      expect(
        visibleBiModules({
          WorkspaceFeature.workspaceStatus,
        }, finance).map((m) => m.id).where(_ids.contains),
        ['sales.revenue_by_kind', 'sales.revenue_by_service'],
      );
      expect(
        visibleBiModules({
          WorkspaceFeature.workspaceStatus,
          WorkspaceFeature.externalRooms,
        }, finance).map((m) => m.id).where(_ids.contains),
        _ids,
      );
      expect(
        visibleBiModules(
          {WorkspaceFeature.workspaceStatus},
          {WorkspacePermission.viewAnalytics},
        ).map((m) => m.id).where(_ids.contains),
        isEmpty,
      );
    });

    test('the server row parses exactly', () {
      final k = salesQualityFromJson(_row());
      expect(
        (k.netMinor, k.grossMinor, k.lines, k.invoices),
        (23500, 28100, 7, 4),
      );
      expect(k.kinds.map((x) => (x.kind, x.netMinor)), [
        ('package', 10000),
        ('subscription', 9000),
        ('service', 2500),
        ('overage', 2000),
      ]);
      expect(k.services.map((s) => (s.rank, s.name, s.netMinor)), [
        (1, 'Ten half-days', 10000),
        (2, 'Coffee', 1500),
        (3, 'Printing', 1000),
      ]);
      expect(
        (k.rooms!.chargesMinor, k.rooms!.costMinor, k.rooms!.marginMinor),
        (53000, 34000, 19000),
      );
      expect(salesMeasure(k, 'sales.room_margin').numerator, 19000);
    });

    test('an amount that cannot travel exactly is unknown, never 0', () {
      final k = salesQualityFromJson(_row(net: '1.5'));
      expect(k.netMinor, isNull);
      expect(k.reasons, contains('amount_not_exact'));
      expect(salesMeasure(k, 'sales.revenue_by_kind').unknown, isTrue);
    });

    test('a line without a readable VAT rate is counted and said, its net '
        'never the gross', () {
      final k = salesQualityFromJson(_row(netUnknown: 2));
      expect(k.netUnknownLines, 2);
      final m = salesMeasure(k, 'sales.revenue_by_kind');
      expect(
        biModuleViews['sales.revenue_by_kind']!.notes(m, l10n, 'en'),
        contains(l10n.biSalesNetUnknown('2')),
      );
    });

    test('a currency mix leaves every amount unknown', () {
      final k = salesQualityFromJson(_row(mixed: true));
      for (final id in _ids) {
        expect(salesMeasure(k, id).unknown, isTrue, reason: id);
      }
      expect(k.lines, 8);
    });

    test('without rented rooms the margin is unknown and says why; the sales '
        'stay', () {
      final k = salesQualityFromJson(_row(rooms: false));
      final margin = salesMeasure(k, 'sales.room_margin');
      expect(margin.unknown, isTrue);
      expect(margin.reasons, contains('external_rooms_off'));
      final sales = salesMeasure(k, 'sales.revenue_by_kind');
      expect(sales.unknown, isFalse);
      expect(sales.reasons, isNot(contains('external_rooms_off')));
      expect(salesRows(k, 'sales.room_margin'), isEmpty);
    });

    test('the rows: kinds by name, services and rooms by their own', () {
      final k = salesQualityFromJson(_row());
      final kinds = biModuleViews['sales.revenue_by_kind']!.labelled(
        salesRows(k, 'sales.revenue_by_kind'),
        l10n,
        'en',
      );
      expect(kinds.map((r) => r.label), [
        l10n.biSalesKindPackage,
        l10n.biSalesKindSubscription,
        l10n.biSalesKindService,
        l10n.biSalesKindOverage,
      ]);
      expect(
        salesRows(
          k,
          'sales.revenue_by_service',
        ).map((r) => (r.label, r.current.numerator)),
        [('Ten half-days', 10000), ('Coffee', 1500), ('Printing', 1000)],
      );
      expect(
        salesRows(
          k,
          'sales.room_margin',
        ).map((r) => (r.label, r.current.numerator)),
        [('Studio', 15000), ('Loft', 4000)],
      );
    });
  });

  group('the Demo computes what pgTAP 354 proves', () {
    test('every sales figure of the month', () async {
      final k = await DemoSalesKpiRepository(
        invoices: _march,
        rooms: FakeRoomRentalRepository(),
        bookings: () => const [],
        roomsEnabled: () => false,
        now: DateTime(2026, 11, 4),
      ).quality('ws', fromMonth: '2025-03', toMonth: '2025-03');
      final server = salesQualityFromJson(_row());
      expect(
        (k.netMinor, k.grossMinor, k.lines, k.invoices),
        (23500, 28100, 7, 4),
      );
      expect(k.kinds, server.kinds);
      expect(k.months, server.months);
      expect(k.services, server.services);
      expect((k.serviceCount, k.serviceNetMinor), (3, 12500));
      expect(k.rooms, isNull);
      expect(k.reasons, ['external_rooms_off']);
    });

    test(
      'a rented room: its bookings charged by its fee, minus its rent',
      () async {
        final rooms = FakeRoomRentalRepository(
          rentals: [
            RoomRental(
              id: 'r1',
              revision: 1,
              officeId: 'o1',
              officeName: 'Studio',
              supplierId: 's1',
              supplierName: 'Landlord',
              availableFrom: DateTime(2025),
              status: RoomRentalStatus.active,
              costCents: 30000,
              currency: 'EUR',
              audienceAll: true,
              fees: const [RoomFee(unit: RoomFeeUnit.halfDay, feeCents: 15000)],
            ),
          ],
        );
        Reservation booking(String id, int day, {bool cancelled = false}) =>
            Reservation(
              id: id,
              workspaceId: 'ws-1',
              officeId: 'o1',
              memberId: 'member-2',
              startsAt: DateTime(2025, 3, day, 9),
              endsAt: DateTime(2025, 3, day, 13),
              status: cancelled
                  ? ReservationStatus.cancelled
                  : ReservationStatus.completed,
            );
        final k = await DemoSalesKpiRepository(
          invoices: () => const [],
          rooms: rooms,
          bookings: () => [
            booking('b1', 3),
            booking('b2', 10),
            booking('b3', 17),
            booking('b4', 24, cancelled: true),
          ],
          roomsEnabled: () => true,
          now: DateTime(2026, 11, 4),
        ).quality('ws', fromMonth: '2025-03', toMonth: '2025-03');
        expect(k.rooms!.rows.single, (
          officeId: 'o1',
          name: 'Studio',
          costKind: 'fixed_per_period',
          uses: 3,
          chargesMinor: 45000,
          costMinor: 30000,
          marginMinor: 15000,
        ));
      },
    );

    test(
      'a dollar invoice leaves every amount unknown, never summed',
      () async {
        final k = await DemoSalesKpiRepository(
          invoices: () => [
            ..._march(),
            _invoice('d9', [
              _line('subscription', 700, label: '100'),
            ], currency: 'USD'),
          ],
          rooms: FakeRoomRentalRepository(),
          bookings: () => const [],
          roomsEnabled: () => false,
          now: DateTime(2026, 11, 4),
        ).quality('ws', fromMonth: '2025-03', toMonth: '2025-03');
        expect(k.reasons, contains('currency_mix'));
        expect((k.netMinor, k.lines), (null, 8));
      },
    );
  });
}

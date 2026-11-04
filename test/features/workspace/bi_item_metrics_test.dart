// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 4 — the item figures: read from `kpi_item_margins` (0675),
// exact to the minor unit, a missing amount never 0; a product never bought
// without a cost; the margins under the space's cost method. The Demo
// computes the same unit prices and margins from pgTAP 355's month.
import 'package:deskilo/core/demo/data/item_kpi_repository.dart';
import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/workspace/domain/bi_modules.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/domain/kpi_items.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/presentation/widgets/bi_module_section.dart';
import 'package:deskilo/features/workspace/providers/bi_item_reader.dart';
import 'package:flutter_test/flutter_test.dart';

const _ids = [
  'items.unit_prices',
  'items.product_margin',
  'items.vendor_margin',
];

/// What pgTAP 355 reads for the owner, March 2025, by the average.
Map<String, Object?> _row({bool mixed = false, Object? margin = '9320'}) {
  String? a(String v) => mixed ? null : v;
  return {
    'from': '2025-03',
    'to': '2025-03',
    'currency': 'EUR',
    'cost_method': 'average',
    'unit_prices': {
      'items': 2,
      'lines': 3,
      'cost_minor': a('9000'),
      'rows': [
        {
          'item_id': 'd2',
          'item': 'Printer paper',
          'supplier_id': 'f2',
          'supplier': 'Beta',
          'units': 10,
          'cost_minor': a('4000'),
          'unit_price_minor': a('400'),
        },
        {
          'item_id': 'd1',
          'item': 'Coffee capsules',
          'supplier_id': 'f1',
          'supplier': 'Alpha',
          'units': 100,
          'cost_minor': a('3000'),
          'unit_price_minor': a('30'),
        },
        {
          'item_id': 'd1',
          'item': 'Coffee capsules',
          'supplier_id': 'f2',
          'supplier': 'Beta',
          'units': 50,
          'cost_minor': a('2000'),
          'unit_price_minor': a('40'),
        },
      ],
    },
    'products': {
      'method': 'average',
      'items': 3,
      'uncosted': 1,
      'revenue_minor': a('13600'),
      'cost_minor': a('3680'),
      'margin_minor': mixed ? null : margin,
      'rows': [
        {
          'item_id': 'd1',
          'item': 'Coffee capsules',
          'units': 60,
          'revenue_minor': a('10000'),
          'unit_cost_minor': a('28'),
          'cost_minor': a('1680'),
          'margin_minor': a('8320'),
        },
        {
          'item_id': 'd2',
          'item': 'Printer paper',
          'units': 5,
          'revenue_minor': a('3000'),
          'unit_cost_minor': a('400'),
          'cost_minor': a('2000'),
          'margin_minor': a('1000'),
        },
        {
          'item_id': 'd3',
          'item': 'Snacks',
          'units': 3,
          'revenue_minor': a('600'),
          'unit_cost_minor': null,
          'cost_minor': null,
          'margin_minor': null,
        },
      ],
    },
    'vendors': {
      'suppliers': 2,
      'margin_minor': a('22000'),
      'rows': [
        {
          'supplier_id': 'f1',
          'supplier': 'Alpha',
          'units': 100,
          'unsold_units': 0,
          'cost_minor': a('3000'),
          'margin_minor': a('13667'),
        },
        {
          'supplier_id': 'f2',
          'supplier': 'Beta',
          'units': 60,
          'unsold_units': 0,
          'cost_minor': a('6000'),
          'margin_minor': a('8333'),
        },
      ],
    },
    'quality': [if (mixed) 'unavailable'],
    'reasons': [if (mixed) 'currency_mix'],
    'computed_at': '2026-11-04T12:00:00Z',
  };
}

PurchaseDetail _bill(
  String id,
  String supplier,
  DateTime dated,
  String item,
  double qty,
  int cents,
) => PurchaseDetail(
  summary: PurchaseSummary(
    id: id,
    supplierId: supplier,
    kind: PurchaseKind.bill,
    state: PurchaseState.approved,
    category: '',
    reference: id,
    currency: 'EUR',
    grossCents: cents,
    originalDate: dated,
    receivedOn: dated,
  ),
  revision: 1,
  sources: const [],
  supplierName: supplier == 'f1' ? 'Alpha' : 'Beta',
  lines: [
    PurchaseLine(
      lineNo: 1,
      description: item,
      grossCents: cents,
      netCents: cents,
      taxCents: 0,
      serviceId: item,
      quantity: qty,
    ),
  ],
);

InvoiceLine _sale(String label, int units, int cents, double vat) =>
    InvoiceLine(
      label: label,
      quantity: units,
      amountCents: cents,
      vatPercent: vat,
    );

Invoice _invoice(List<InvoiceLine> lines) => Invoice(
  id: 'i1',
  workspaceId: 'ws-1',
  memberId: 'member-2',
  number: 'I-1',
  issuedAt: DateTime(2025, 3, 31),
  period: '2025-03',
  title: 'T',
  lines: lines,
  totalCents: lines.fold(0, (s, l) => s + l.amountCents),
  currency: 'EUR',
  memberName: 'Name',
  memberAddress: '',
  workspaceName: 'Items',
  workspaceAddress: '',
  issuerName: 'Owner',
  signature: 's',
  kind: InvoiceKind.usage,
);

void main() {
  group('the contract', () {
    test('the three cards need the purchase figures and the finance right', () {
      final modules = {for (final m in biModules) m.id: m};
      for (final id in _ids) {
        expect(
          modules[id]?.feature,
          WorkspaceFeature.purchaseAnalytics,
          reason: id,
        );
        expect(kpiDefinitionOf(id), isNotNull, reason: id);
        expect(biModuleViews[id], isNotNull, reason: id);
      }
      expect(
        visibleBiModules(
          {WorkspaceFeature.purchaseAnalytics},
          {WorkspacePermission.viewAnalytics},
        ).map((m) => m.id).where(_ids.contains),
        isEmpty,
      );
    });

    test('the server row parses exactly', () {
      final k = itemMarginsFromJson(_row());
      expect(k.costMethod, 'average');
      expect(k.prices.map((p) => (p.item, p.supplier, p.unitPriceMinor)), [
        ('Printer paper', 'Beta', 400),
        ('Coffee capsules', 'Alpha', 30),
        ('Coffee capsules', 'Beta', 40),
      ]);
      expect(
        (k.productMarginMinor, k.uncosted, k.revenueMinor),
        (9320, 1, 13600),
      );
      expect(
        k.products.last.marginMinor,
        isNull,
        reason: 'never bought: no cost',
      );
      expect(k.vendors.map((v) => (v.supplier, v.marginMinor)), [
        ('Alpha', 13667),
        ('Beta', 8333),
      ]);
    });

    test('an amount that cannot travel exactly is unknown, never 0', () {
      final k = itemMarginsFromJson(_row(margin: '1.5'));
      expect(k.reasons, contains('amount_not_exact'));
      expect(itemMeasure(k, 'items.product_margin').unknown, isTrue);
    });

    test('a currency mix leaves every amount unknown, the counts stay', () {
      final k = itemMarginsFromJson(_row(mixed: true));
      for (final id in _ids) {
        expect(itemMeasure(k, id).unknown, isTrue, reason: id);
      }
      expect(k.productCount, 3);
    });

    test('the rows: an item from a supplier, a product, a supplier', () {
      final k = itemMarginsFromJson(_row());
      expect(
        itemRows(
          k,
          'items.unit_prices',
        ).map((r) => (r.label, r.current.numerator)),
        [
          ('Printer paper · Beta', 400),
          ('Coffee capsules · Alpha', 30),
          ('Coffee capsules · Beta', 40),
        ],
      );
      final products = itemRows(k, 'items.product_margin');
      expect(products.map((r) => r.label), [
        'Coffee capsules',
        'Printer paper',
        'Snacks',
      ]);
      expect(products.last.current.unknown, isTrue);
      expect(
        itemRows(k, 'items.vendor_margin').map((r) => r.current.numerator),
        [13667, 8333],
      );
    });
  });

  test('the Demo computes what pgTAP 355 proves', () async {
    final purchases = FakePurchaseRepository()
      ..add(_bill('b1', 'f1', DateTime(2025, 2, 10), 'd1', 100, 2000))
      ..add(_bill('b2', 'f1', DateTime(2025, 3, 5), 'd1', 100, 3000))
      ..add(_bill('b3', 'f2', DateTime(2025, 3, 12), 'd1', 50, 2000))
      ..add(_bill('b4', 'f2', DateTime(2025, 3, 15), 'd2', 10, 4000))
      ..add(_bill('b5', 'f1', DateTime(2025, 4, 2), 'd1', 100, 10000));
    final k = await DemoItemKpiRepository(
      purchases: purchases,
      invoices: () => [
        _invoice([
          _sale('Coffee capsules', 40, 8000, 20),
          _sale('Coffee capsules', 20, 4000, 20),
          _sale('Printer paper', 5, 3000, 0),
          _sale('Snacks', 3, 600, 0),
        ]),
      ],
      services: () => const [
        ServiceItem(
          id: 'd1',
          workspaceId: 'ws-1',
          name: 'Coffee capsules',
          priceCents: 200,
          active: true,
        ),
        ServiceItem(
          id: 'd2',
          workspaceId: 'ws-1',
          name: 'Printer paper',
          priceCents: 600,
          active: true,
        ),
        ServiceItem(
          id: 'd3',
          workspaceId: 'ws-1',
          name: 'Snacks',
          priceCents: 200,
          active: true,
        ),
      ],
      now: DateTime(2026, 11, 4),
    ).quality('ws', fromMonth: '2025-03', toMonth: '2025-03');
    final server = itemMarginsFromJson(_row());
    expect(k.prices, server.prices);
    expect(k.products, server.products);
    expect(k.vendors, server.vendors);
    expect(
      (
        k.purchaseCostMinor,
        k.productMarginMinor,
        k.vendorMarginMinor,
        k.uncosted,
      ),
      (9000, 9320, 22000, 1),
    );
  });
}

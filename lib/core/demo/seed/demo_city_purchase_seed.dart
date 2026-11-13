// SPDX-License-Identifier: AGPL-3.0-or-later
// Synthetic purchases; no vendor is contacted.
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../features/money/domain/purchase.dart';
import '../data/einvoice_inbox_repository.dart';
import '../data/purchase_repository.dart';
import '../data/supplier_repository.dart';
import 'demo_london_seed.dart';
import 'demo_new_york_seed.dart';
import 'demo_purchase_seed.dart';
import 'demo_trade_city_seed.dart';

DemoPurchasing cityPurchasing(
  DateTime now, {
  required bool tenant,
  required String Function() actor,
  required List<String> siteIds,
}) {
  final suppliers = FakeSupplierRepository();
  final purchases = FakePurchaseRepository(
    actor: actor,
    functionalCurrency: tenant ? 'USD' : 'GBP',
    workspaceId: tenant ? demoNewYorkSpaceId : demoLondonSpaceId,
  );
  final prefix = tenant ? 'ny' : 'uk';
  final country = tenant ? 'US' : 'GB';
  final vending = Supplier(
    id: '$prefix-vending',
    number: '2',
    name: 'Metro Vending Rentals (Demo)',
    countryCode: country,
  );
  final stock = Supplier(
    id: '$prefix-stock',
    number: '3',
    name: 'Neighbourhood Wholesale (Demo)',
    countryCode: country,
    contact: 'orders@neighbourhood.example.test',
  );
  final drinks = Supplier(
    id: '$prefix-drinks',
    number: '4',
    name: 'City Drinks Wholesale (Demo)',
    countryCode: country,
    contact: 'orders@citydrinks.example.test',
  );
  final amazon = Supplier(
    id: '$prefix-amazon',
    number: '5',
    name: 'Amazon Business (Demo)',
    countryCode: country,
    contact: 'orders@amazon-simulation.example.test',
  );
  suppliers.suppliers.addAll([vending, stock, drinks, amazon]);
  if (tenant) _landlordBills(now, suppliers, purchases);
  _siteBills(
    now,
    (prefix: prefix, currency: tenant ? 'USD' : 'GBP', years: tenant ? 4 : 3),
    siteIds,
    purchases,
    (vending: vending, stock: stock, drinks: drinks, amazon: amazon),
  );
  _pendingBill(now, prefix, tenant ? 'USD' : 'GBP', stock, purchases);
  return DemoPurchasing(
    suppliers: suppliers,
    inbox: FakeEInvoiceInboxRepository(),
    purchases: purchases,
  );
}

/// #3832 — the purchase side of a trade city: its suppliers, a monthly run
/// of approved and paid bills per site in the city's own currency, one bill
/// that waits for approval, and one bill from a supplier abroad: in another
/// currency, with the rate it was entered at kept apart from the bill.
DemoPurchasing tradeCityPurchasing(
  DemoTradeCity city,
  DateTime now, {
  required String Function() actor,
}) {
  final prefix = city.prefix, country = city.countryCode;
  final suppliers = FakeSupplierRepository();
  final purchases = FakePurchaseRepository(
    actor: actor,
    functionalCurrency: city.currency,
    workspaceId: city.id,
  );
  Supplier local(String kind, String number, String name) => Supplier(
    id: '$prefix-$kind',
    number: number,
    name: '${city.vendorStem} $name (Demo)',
    city: city.city,
    countryCode: country,
    contact: 'orders@$prefix-$kind.example.test',
  );
  final vendors = (
    vending: local('vending', '2', 'Vending Rentals'),
    stock: local('stock', '3', 'Snack Wholesale'),
    drinks: local('drinks', '4', 'Drinks Wholesale'),
    amazon: local('print', '5', 'Office and Print Supplies'),
  );
  final abroad = Supplier(
    id: '$prefix-abroad',
    number: '6',
    name: '${city.vendorStem} Booking Software (Demo)',
    countryCode: city.foreignCurrency == 'EUR' ? 'DE' : 'CH',
    contact: 'billing@$prefix-abroad.example.test',
  );
  suppliers.suppliers.addAll([
    vendors.vending,
    vendors.stock,
    vendors.drinks,
    vendors.amazon,
    abroad,
  ]);
  _siteBills(
    now,
    (
      prefix: prefix,
      currency: city.currency,
      years: DemoTradeCity.years,
    ),
    city.siteIds,
    purchases,
    vendors,
  );
  _pendingBill(now, prefix, city.currency, vendors.stock, purchases);
  _foreignBill(now, city, abroad, purchases);
  return DemoPurchasing(
    suppliers: suppliers,
    inbox: FakeEInvoiceInboxRepository(),
    purchases: purchases,
  );
}

/// A yearly licence billed in [DemoTradeCity.foreignCurrency], sent for
/// approval at the rate entered with it: the approver confirms the rate. The
/// bill keeps its own currency; the books are kept in the city's.
void _foreignBill(
  DateTime now,
  DemoTradeCity city,
  Supplier supplier,
  FakePurchaseRepository purchases,
) {
  final received = now.subtract(const Duration(days: 5));
  final id = '${city.prefix}-bill-abroad';
  final summary = PurchaseSummary(
    id: id,
    supplierId: supplier.id,
    kind: PurchaseKind.bill,
    state: PurchaseState.draft,
    category: 'Booking software, yearly licence',
    reference: '${city.prefix.toUpperCase()}-ABROAD-1',
    currency: city.foreignCurrency,
    grossCents: 48000,
    receivedOn: received,
  );
  purchases
    ..rememberRate(
      summary,
      ExchangeRateEntry(
        rate: ExactDecimal.parse(city.foreignRate),
        rateDate: received,
        source: 'tax_authority',
      ),
    )
    ..addPendingBill(
      PurchaseDetail(
        summary: summary,
        revision: 1,
        sources: const [],
        supplierName: supplier.name,
        supplierNumber: supplier.number,
        lines: const [
          PurchaseLine(
            lineNo: 1,
            description: 'Booking software, yearly licence',
            grossCents: 48000,
          ),
        ],
        dueOn: now.add(const Duration(days: 25)),
      ),
    );
}

typedef _VendorSet = ({
  Supplier vending,
  Supplier stock,
  Supplier drinks,
  Supplier amazon,
});
typedef _Bill = ({
  String id,
  Supplier supplier,
  DateTime month,
  String currency,
  String title,
  List<PurchaseLine> lines,
  bool paid,
});

void _landlordBills(
  DateTime now,
  FakeSupplierRepository suppliers,
  FakePurchaseRepository purchases,
) {
  const landlord = Supplier(
    id: 'ny-landlord',
    number: '1',
    name: 'Hudson Property Company (Demo)',
    city: 'New York',
    countryCode: 'US',
  );
  suppliers.suppliers.add(landlord);
  for (
    var month = DateTime(now.year - 4, now.month);
    month.isBefore(DateTime(now.year, now.month));
    month = DateTime(month.year, month.month + 1)
  ) {
    final period = yearMonth(month.year, month.month);
    _recordBill(purchases, (
      id: 'ny-rent-$period',
      supplier: landlord,
      month: month,
      currency: 'USD',
      title: 'Rent and service fees',
      paid: true,
      lines: const [
        PurchaseLine(
          lineNo: 1,
          description: 'Monthly rent',
          grossCents: 600000,
        ),
        PurchaseLine(lineNo: 2, description: 'Service fees', grossCents: 80000),
      ],
    ), now);
  }
}

void _siteBills(
  DateTime now,
  ({String prefix, String currency, int years}) books,
  List<String> siteIds,
  FakePurchaseRepository purchases,
  _VendorSet vendors,
) {
  final (:prefix, :currency, :years) = books;
  final start = DateTime(now.year - years, now.month);
  for (
    var month = start;
    month.isBefore(DateTime(now.year, now.month));
    month = DateTime(month.year, month.month + 1)
  ) {
    final period = yearMonth(month.year, month.month);
    for (final (index, siteId) in siteIds.indexed) {
      for (final (kind, supplier, cents, title) in [
        ('machine', vendors.vending, 4500, 'Vending machine rental'),
        (
          'stock',
          vendors.stock,
          3500 + index * 200,
          'Sweets and snacks restock',
        ),
        (
          'drinks',
          vendors.drinks,
          3500 + index * 300,
          'Water and beer restock',
        ),
        (
          'print',
          vendors.amazon,
          1500 + index * 200,
          'Paper, ink and 3D printing materials',
        ),
        if (month == start)
          (
            'equipment',
            vendors.amazon,
            220000,
            'Colour, mono, copy and 3D printers',
          ),
      ]) {
        _recordBill(purchases, (
          id: '$prefix-$kind-$period-$index',
          supplier: supplier,
          month: month,
          currency: currency,
          title: title,
          paid: !(kind == 'stock' && index == 0 &&
              month == DateTime(now.year, now.month - 1)),
          lines: [
            PurchaseLine(
              lineNo: 1,
              description: title,
              grossCents: cents,
              costSiteId: siteId,
              // #3294 step 4 — the restocks name the catalogue item they buy.
              serviceId: _restock(prefix, kind)?.item,
              quantity: _restock(prefix, kind)?.quantity ?? 1,
              // #3785 — the server's classes (0461): an operating cost is
              // `operating`, never a word the server refuses.
              recognitionKind: kind == 'equipment'
                  ? 'asset'
                  : kind == 'stock'
                  ? 'stock'
                  : 'operating',
            ),
          ],
        ), now);
      }
    }
  }
}

void _recordBill(FakePurchaseRepository purchases, _Bill bill, DateTime now) {
  final (:id, :supplier, :month, :currency, :title, :lines, :paid) = bill;
  final cents = lines.fold<int>(0, (sum, line) => sum + line.grossCents);
  // #3294 step 2 — a bill reaches the space a few days after the date the
  // supplier put on it, falls due a month later and is mostly paid before
  // then; one in four is paid after its due date (never after today).
  final seed = id.codeUnits.fold<int>(0, (sum, c) => sum + c);
  final received = month.add(Duration(days: seed % 6));
  final due = month.add(const Duration(days: 30));
  final paidOn = month.add(Duration(days: seed % 4 == 0 ? 34 : 25));
  final summary = PurchaseSummary(
    id: id,
    supplierId: supplier.id,
    kind: PurchaseKind.bill,
    state: PurchaseState.approved,
    category: title,
    reference: id,
    currency: currency,
    grossCents: cents,
    originalDate: month,
    receivedOn: received,
  );
  final obligation = PurchaseObligation(
    id: '$id-payable',
    purchaseId: id,
    creditorKind: CreditorKind.supplier,
    creditorId: supplier.id,
    creditorName: supplier.name,
    amountCents: cents,
    currency: currency,
    dueOn: due,
    appliedCents: 0,
    paidCents: paid ? cents : 0,
    remainingCents: paid ? 0 : cents,
    allocations: [
      if (paid)
      SettlementAllocation(
        id: '$id-payment',
        isReversal: false,
        amountCents: cents,
        method: 'bank_transfer',
        reference: 'Demo payment',
        paidOn: paidOn.isAfter(now) ? now : paidOn,
      ),
    ],
  );
  purchases
    ..add(
      PurchaseDetail(
        summary: summary,
        revision: 1,
        sources: const [],
        supplierName: supplier.name,
        supplierNumber: supplier.number,
        lines: lines,
        dueOn: due,
      ),
    )
    ..payables.add(PayableRow(obligation: obligation, purchase: summary));
}

void _pendingBill(DateTime now, String prefix, String currency,
    Supplier supplier, FakePurchaseRepository purchases) {
  purchases.add(PurchaseDetail(
    summary: PurchaseSummary(
      id: '$prefix-bill-pending', supplierId: supplier.id,
      kind: PurchaseKind.bill, state: PurchaseState.pending,
      category: 'Refreshments', reference: '$prefix-pending-supplies',
      currency: currency, grossCents: 6400, receivedOn: now,
    ),
    revision: 1, sources: const [], supplierName: supplier.name,
    supplierNumber: supplier.number,
    lines: const [PurchaseLine(lineNo: 1, description: 'Snacks and drinks', grossCents: 6400)],
  ));
}

/// #3294 step 4 — what a restock bill of [kind] buys from the city
/// catalogue (its snacks and bottled water), and how many; null for a bill
/// that buys no catalogue item.
({String item, double quantity})? _restock(String prefix, String kind) =>
    switch (kind) {
      'stock' => (item: '$prefix-service-3', quantity: 50),
      'drinks' => (item: '$prefix-service-2', quantity: 40),
      _ => null,
    };

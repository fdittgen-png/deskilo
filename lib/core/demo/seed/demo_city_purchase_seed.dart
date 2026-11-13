// SPDX-License-Identifier: AGPL-3.0-or-later
// Synthetic purchases; no vendor is contacted.
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart' show vatSplit;
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../features/money/domain/purchase.dart';
import '../data/einvoice_inbox_repository.dart';
import '../data/purchase_repository.dart';
import '../data/supplier_repository.dart';
import 'demo_purchase_seed.dart';

typedef DemoCityPurchaseSpec = ({String workspaceId, String prefix,
  String country, String currency, int years, double vatPercent});

typedef DemoCityPurchaseLabels = ({String rentalSupplier, String materialsSupplier, String materialsContact,
  String rental, String stock, String materials, String pending});

const DemoCityPurchaseLabels _demoCityPurchaseLabels = (
  rentalSupplier: 'Metro Vending Rentals (Demo)',
  materialsSupplier: 'City Drinks Wholesale (Demo)',
  materialsContact: 'orders@citydrinks.example.test',
  rental: 'Vending machine rental', stock: 'Sweets and snacks restock',
  materials: 'Water and beer restock', pending: 'Snacks and drinks',
);

DemoPurchasing cityPurchasing(
  DateTime now, {
  required DemoCityPurchaseSpec spec,
  bool tenant = false,
  required String Function() actor,
  required List<String> siteIds,
  DemoCityPurchaseLabels labels = _demoCityPurchaseLabels,
}) {
  final (:workspaceId, :prefix, :country, :currency, :years, :vatPercent) = spec;
  final suppliers = FakeSupplierRepository();
  final purchases = FakePurchaseRepository(
    actor: actor,
    functionalCurrency: currency,
    workspaceId: workspaceId,
  );
  final vending = Supplier(
    id: '$prefix-vending',
    number: '2',
    name: labels.rentalSupplier,
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
    name: labels.materialsSupplier,
    countryCode: country,
    contact: labels.materialsContact,
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
  _siteBills(now, (prefix: prefix, currency: currency, years: years, vatPercent: vatPercent, labels: labels), siteIds, purchases, (
    vending: vending,
    stock: stock,
    drinks: drinks,
    amazon: amazon,
  ));
  _pendingBill(now, spec, stock, purchases, labels.pending);
  return DemoPurchasing(
    suppliers: suppliers,
    inbox: FakeEInvoiceInboxRepository(),
    purchases: purchases,
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
  ({String prefix, String currency, int years, double vatPercent, DemoCityPurchaseLabels labels}) spec,
  List<String> siteIds,
  FakePurchaseRepository purchases,
  _VendorSet vendors,
) {
  final prefix = spec.prefix, currency = spec.currency;
  final start = DateTime(now.year - spec.years, now.month);
  for (
    var month = start;
    month.isBefore(DateTime(now.year, now.month));
    month = DateTime(month.year, month.month + 1)
  ) {
    final period = yearMonth(month.year, month.month);
    for (final (index, siteId) in siteIds.indexed) {
      for (final (kind, supplier, cents, title) in [
        ('machine', vendors.vending, 4500, spec.labels.rental),
        (
          'stock',
          vendors.stock,
          3500 + index * 200,
          spec.labels.stock,
        ),
        (
          'drinks',
          vendors.drinks,
          3500 + index * 300,
          spec.labels.materials,
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
              netCents: vatSplit(cents, spec.vatPercent).netCents,
              taxCents: vatSplit(cents, spec.vatPercent).vatCents,
              taxRatePercent: spec.vatPercent,
              recoverableTaxCents: vatSplit(cents, spec.vatPercent).vatCents,
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

void _pendingBill(DateTime now, DemoCityPurchaseSpec spec,
    Supplier supplier, FakePurchaseRepository purchases, String label) {
  final prefix = spec.prefix, currency = spec.currency, vatPercent = spec.vatPercent;
  purchases.add(PurchaseDetail(
    summary: PurchaseSummary(
      id: '$prefix-bill-pending', supplierId: supplier.id,
      kind: PurchaseKind.bill, state: PurchaseState.pending,
      category: label, reference: '$prefix-pending-supplies',
      currency: currency, grossCents: 6400, receivedOn: now,
    ),
    revision: 1, sources: const [], supplierName: supplier.name,
    supplierNumber: supplier.number,
    lines: [PurchaseLine(lineNo: 1, description: label, grossCents: 6400,
      netCents: vatSplit(6400, vatPercent).netCents, taxCents: vatSplit(6400, vatPercent).vatCents, taxRatePercent: vatPercent,
      recoverableTaxCents: vatSplit(6400, vatPercent).vatCents,
      recognitionKind: 'stock', serviceId: '$prefix-service-3', quantity: 32)],
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

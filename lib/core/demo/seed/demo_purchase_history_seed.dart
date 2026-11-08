// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3292 — the purchases the rest of the Demo already points at. The lease's
// rent occurrences were matched to bills `demo-bill-rent-<k>` and the
// equipment register to purchases `demo-purchase-machine`, `-printer` and
// `-ladder`, none of which the space held: opening one answered "unknown
// purchase". They are seeded here from the same rules as their referrers —
// one approved rent bill of the lessor a month from the lease's start to last
// month (last month's already indexed), paid on its due day, and the three
// equipment bills, approved and paid — so every reference resolves and the
// books post what the lease and the register show.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../features/money/domain/purchase.dart';
import '../data/purchase_repository.dart';

/// The month the Demo's equipment came into use: the last March not after
/// [now] (#3292 — never a date ahead of the Demo).
DateTime demoEquipmentInUseOn(DateTime now) =>
    DateTime(now.month >= 3 ? now.year : now.year - 1, 3);

PurchaseLine _line(int no, String what, int gross, double rate) {
  final split = vatSplit(gross, rate);
  return PurchaseLine(
    lineNo: no,
    description: what,
    grossCents: gross,
    netCents: split.netCents,
    taxCents: split.vatCents,
    taxRatePercent: rate,
    recoverableTaxCents: split.vatCents,
  );
}

/// An approved bill, paid in full by transfer on [paidOn].
void _paidBill(
  FakePurchaseRepository purchases, {
  required String id,
  required String reference,
  required DateTime received,
  required DateTime paidOn,
  required List<PurchaseLine> lines,
  String? supplierId,
  required String supplierName,
}) {
  final gross = lines.fold(0, (int n, l) => n + l.grossCents);
  final summary = PurchaseSummary(
    id: id,
    supplierId: supplierId,
    kind: PurchaseKind.bill,
    state: PurchaseState.approved,
    category: lines.first.description,
    reference: reference,
    currency: 'EUR',
    grossCents: gross,
    receivedOn: received,
  );
  purchases
    ..add(
      PurchaseDetail(
        summary: summary,
        revision: 1,
        lines: lines,
        sources: const [],
        supplierName: supplierName,
        dueOn: paidOn,
      ),
    )
    ..payables.add(
      PayableRow(
        obligation: PurchaseObligation(
          id: 'demo-payable-$id',
          purchaseId: id,
          creditorKind: CreditorKind.supplier,
          creditorId: supplierId ?? '',
          creditorName: supplierName,
          amountCents: gross,
          currency: 'EUR',
          paidCents: gross,
          appliedCents: 0,
          remainingCents: 0,
          allocations: [
            SettlementAllocation(
              id: 'demo-allocation-$id',
              isReversal: false,
              amountCents: gross,
              method: 'bank_transfer',
              reference: reference,
              paidOn: paidOn,
            ),
          ],
        ),
        purchase: summary,
      ),
    );
}

/// Seeds the lessor's past rent bills and the equipment bills on [purchases].
void seedDemoPurchaseHistory(FakePurchaseRepository purchases, DateTime now) {
  // The lease's own calendar (demo_lease_seed.dart): from July of last year.
  final starts = DateTime(now.year - 1, 7);
  final months = (now.year - starts.year) * 12 + now.month - starts.month + 1;
  for (var k = 0; k < months - 1; k++) {
    final due = DateTime(starts.year, starts.month + k);
    // Last month's bill already carries the July indexation.
    final indexed = k == months - 2;
    _paidBill(
      purchases,
      id: 'demo-bill-rent-$k',
      reference: 'LOY-${yearMonth(due.year, due.month)}',
      received: due.subtract(const Duration(days: 5)),
      paidOn: due,
      lines: [
        _line(1, 'Rent of the premises', indexed ? 225000 : 222000, 20),
      ],
      supplierId: 'demo-supplier-landlord',
      supplierName: 'SCI Les Remparts',
    );
  }
  final inUse = demoEquipmentInUseOn(now);
  final today = DateTime(now.year, now.month, now.day);
  // The register states the machine at 1,200.00 net, its VAT recovered.
  _paidBill(
    purchases,
    id: 'demo-purchase-machine',
    reference: 'CM-2026-014',
    received: inUse.subtract(const Duration(days: 9)),
    paidOn: inUse.subtract(const Duration(days: 2)),
    lines: [_line(1, 'Espresso machine, kitchen', 144000, 20)],
    supplierName: 'Café du Midi',
  );
  _paidBill(
    purchases,
    id: 'demo-purchase-printer',
    reference: 'BP-8841',
    received: today.subtract(const Duration(days: 20)),
    paidOn: today.subtract(const Duration(days: 12)),
    lines: [_line(1, 'Colour printer, reception', 57600, 20)],
    supplierName: 'Bureau Plus',
  );
  _paidBill(
    purchases,
    id: 'demo-purchase-ladder',
    reference: 'BP-3320',
    received: today.subtract(const Duration(days: 10)),
    paidOn: today.subtract(const Duration(days: 3)),
    lines: [
      _line(1, 'Light bulbs', 2400, 20),
      _line(2, 'Folding ladder', 18900, 20),
    ],
    supplierName: 'Bricolage Pézenas',
  );
}

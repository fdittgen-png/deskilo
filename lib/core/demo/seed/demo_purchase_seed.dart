// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The purchase side of the demo space: the people it buys from, the supplier
// invoices that arrived by e-invoice, the bills captured from them and the
// receipts members paid out of pocket -- approved, waiting and refused -- with
// the claims they leave and a payment already made. Dates follow the seeded
// instant; a bill is due before the end of the year.
import '../../../features/money/domain/einvoice_inbox.dart';
import '../../../features/money/domain/invoice.dart';
import '../../../features/money/domain/purchase.dart';
import '../../../features/money/domain/supplier.dart';
import '../../../features/money/domain/vat_rate.dart';
import '../../time/date_text.dart';
import '../data/einvoice_inbox_repository.dart';
import '../data/money_repository.dart';
import '../data/purchase_repository.dart';
import '../data/supplier_repository.dart';

/// The three in-memory repositories of the purchase side, seeded.
class DemoPurchasing {
  const DemoPurchasing({
    required this.suppliers,
    required this.inbox,
    required this.purchases,
  });

  final FakeSupplierRepository suppliers;
  final FakeEInvoiceInboxRepository inbox;
  final FakePurchaseRepository purchases;
}

DemoPurchasing seedDemoPurchasing(DateTime now, {FakeMoneyRepository? money}) {
  final suppliers = FakeSupplierRepository()..suppliers.addAll(_suppliers);
  final inbox = FakeEInvoiceInboxRepository();
  final purchases = FakePurchaseRepository.demo();
  final today = DateTime(now.year, now.month, now.day);
  if (money != null) {
    purchases.onOffset = (invoiceId, cents) =>
        _settle(money, invoiceId, cents, now);
  }
  _seedInbox(inbox, today);
  _seedBills(purchases, today);
  _seedReimbursedReceipt(purchases, today);
  return DemoPurchasing(
    suppliers: suppliers,
    inbox: inbox,
    purchases: purchases,
  );
}

const _suppliers = [
  Supplier(
    id: 'demo-supplier-landlord',
    number: '1',
    name: 'SCI Les Remparts',
    taxIdEntered: 'FR 40 303 265 045',
    taxIdentifier: 'FR40303265045',
    street: '4 rue de la Foire',
    postalCode: '34120',
    city: 'Pézenas',
    countryCode: 'FR',
    contact: 'gestion@remparts.example',
    bankRevision: 1,
  ),
  Supplier(
    id: 'demo-supplier-cleaning',
    number: '2',
    name: 'Net & Clair SARL',
    taxIdEntered: 'FR 12 345 678 901',
    taxIdentifier: 'FR12345678901',
    street: '12 avenue de Verdun',
    postalCode: '34500',
    city: 'Béziers',
    countryCode: 'FR',
    bankRevision: 1,
  ),
  Supplier(
    id: 'demo-supplier-telecom',
    number: '3',
    name: 'Opale Télécom',
    taxIdEntered: 'FR 98 765 432 109',
    taxIdentifier: 'FR98765432109',
    city: 'Montpellier',
    countryCode: 'FR',
  ),
  Supplier(
    id: 'demo-supplier-coffee',
    number: '4',
    name: 'Torréfacteur du Midi',
    city: 'Sète',
    countryCode: 'FR',
  ),
  Supplier(
    id: 'demo-supplier-bank',
    number: '6',
    name: 'Crédit Méridional',
    city: 'Béziers',
    countryCode: 'FR',
  ),
  Supplier(
    id: 'demo-supplier-energy',
    number: '5',
    name: 'Énergie du Languedoc',
    taxIdEntered: 'FR 55 123 456 789',
    taxIdentifier: 'FR55123456789',
    city: 'Montpellier',
    countryCode: 'FR',
  ),
  // The lessor of the rented annex room (demo_room_seed.dart).
  Supplier(
    id: 'demo-supplier-immo',
    number: '7',
    name: 'Immobilière du Midi',
    city: 'Pézenas',
    countryCode: 'FR',
  ),
];

/// The supplier invoices that arrived by e-invoice: one waiting, one matched
/// to an expense, one refused because it is not addressed to this space.
void _seedInbox(FakeEInvoiceInboxRepository inbox, DateTime today) {
  String ago(int days) => isoDay(today.subtract(Duration(days: days)));
  inbox.documents.addAll([
    InboxDocument(
      id: 'demo-inbox-telecom',
      number: 'OT-2026-4411',
      issueDate: ago(3),
      currency: 'EUR',
      supplierName: 'Opale Télécom',
      grossCents: 5880,
      status: InboxStatus.received,
      supplierId: 'demo-supplier-telecom',
      supplierNumber: '3',
    ),
    InboxDocument(
      id: 'demo-inbox-cleaning',
      number: 'NC-8810',
      issueDate: ago(9),
      currency: 'EUR',
      supplierName: 'Net & Clair SARL',
      grossCents: 14400,
      status: InboxStatus.matched,
      supplierId: 'demo-supplier-cleaning',
      supplierNumber: '2',
    ),
    InboxDocument(
      id: 'demo-inbox-unknown',
      number: 'X-77',
      issueDate: ago(20),
      currency: 'EUR',
      supplierName: 'Fournitures Express',
      grossCents: 23750,
      status: InboxStatus.rejected,
      rejectReason: 'Not addressed to this space',
    ),
  ]);
}

/// One line of a document at a French rate (null: the document did not say).
PurchaseLine _bought(int no, String what, int gross, double? rate) {
  final split = rate == null ? null : vatSplit(gross, rate);
  return PurchaseLine(
    lineNo: no,
    description: what,
    grossCents: gross,
    netCents: split?.netCents,
    taxCents: split?.vatCents,
    taxRatePercent: rate,
    recoverableTaxCents: split?.vatCents,
  );
}

/// Who and when around a document: its reference, the day it arrived, the
/// supplier and the due date when it has them.
typedef _Meta = ({
  String reference,
  DateTime received,
  Supplier? supplier,
  DateTime? dueOn,
});

_Meta _meta(
  String reference,
  DateTime received, {
  Supplier? supplier,
  DateTime? dueOn,
}) => (
  reference: reference,
  received: received,
  supplier: supplier,
  dueOn: dueOn,
);

PurchaseDetail _document(
  String id,
  PurchaseKind kind,
  PurchaseState state,
  _Meta meta,
  List<PurchaseLine> lines,
) => PurchaseDetail(
  summary: PurchaseSummary(
    id: id,
    kind: kind,
    state: state,
    category: lines.first.description,
    reference: meta.reference,
    currency: 'EUR',
    grossCents: lines.fold(0, (s, l) => s + l.grossCents),
    receivedOn: meta.received,
  ),
  revision: 1,
  lines: lines,
  sources: const [],
  supplierName: meta.supplier?.name,
  supplierNumber: meta.supplier?.number,
  dueOn: meta.dueOn,
);

/// Bills captured from supplier invoices (the rent at 20 %, the cleaning at
/// 20 %, the energy bill at 5.5 % and 20 %, a catering bill at 10 %, a bank
/// statement with no VAT), a credit note, and the receipts members paid.
void _seedBills(FakePurchaseRepository purchases, DateTime today) {
  final nextFirst = DateTime(today.year, today.month + 1);
  final endOfYear = DateTime(today.year, 12, 31);
  DateTime due(DateTime d) => d.isAfter(endOfYear) ? endOfYear : d;
  DateTime inDays(int days) => due(today.add(Duration(days: days)));
  DateTime ago(int days) => today.subtract(Duration(days: days));
  final cleaning = _suppliers[1];
  const draft = PurchaseState.draft;
  const bill = PurchaseKind.bill;
  purchases
    ..add(
      _document(
        'demo-bill-rent',
        bill,
        draft,
        _meta(
          'LOY-${nextFirst.year}-${twoDigits(nextFirst.month)}',
          today,
          supplier: _suppliers[0],
          dueOn: due(nextFirst),
        ),
        [_bought(1, 'Rent of the premises', 222000, 20)],
      ),
    )
    ..add(
      _document(
        'demo-bill-energy',
        bill,
        draft,
        _meta('EDL-0457', ago(4), supplier: _suppliers[5], dueOn: inDays(12)),
        [
          _bought(1, 'Electricity, subscription', 1500, 5.5),
          _bought(2, 'Electricity, 1,740 kWh', 30360, 20),
        ],
      ),
    )
    ..add(
      _document(
        'demo-bill-energy-unread',
        bill,
        draft,
        _meta('EAU-17', ago(1), dueOn: inDays(25)),
        [_bought(1, 'Water, quarter', 8620, null)],
      ),
    )
    ..add(
      _document(
        'demo-credit-cleaning',
        PurchaseKind.creditNote,
        draft,
        _meta('NC-AV-12', today, supplier: cleaning),
        [_bought(1, 'Cleaning, missed visit', 2400, 20)],
      ),
    )
    ..add(
      _document(
        'demo-receipt-pending',
        PurchaseKind.memberReceipt,
        PurchaseState.pending,
        _meta('', today),
        [_bought(1, 'Coffee beans', 3600, 5.5)],
      ),
    )
    ..add(
      _document(
        'demo-receipt-refused',
        PurchaseKind.memberReceipt,
        PurchaseState.rejected,
        _meta('', ago(6)),
        [_bought(1, 'Tools', 9000, 20)],
      ),
    )
    // Approved by a second person and now owed to the supplier: the cleaning
    // bill part-paid, the bank charges paid in full; the catering bill waits.
    ..addApprovedBill(
      _document(
        'demo-bill-cleaning',
        bill,
        draft,
        _meta('NC-8810', ago(9), supplier: cleaning, dueOn: inDays(20)),
        [_bought(1, 'Cleaning, month', 14400, 20)],
      ),
      'demo-supplier-cleaning',
      payments: [
        SettlementAllocation(
          id: 'demo-sup-alloc-1',
          isReversal: false,
          amountCents: 10000,
          method: 'bank_transfer',
          reference: 'Wire NC-8810 (part)',
          paidOn: ago(3),
        ),
      ],
    )
    ..addApprovedBill(
      _document(
        'demo-bill-bank',
        bill,
        draft,
        _meta('BQ-Q3', ago(15), supplier: _suppliers[4], dueOn: inDays(5)),
        [_bought(1, 'Bank charges', 1500, 0)],
      ),
      'demo-supplier-bank',
      payments: [
        SettlementAllocation(
          id: 'demo-sup-alloc-2',
          isReversal: false,
          amountCents: 1500,
          method: 'card',
          reference: 'Direct debit',
          paidOn: ago(12),
        ),
      ],
    )
    // Approved and not paid yet: the first line of To pay.
    ..addApprovedBill(
      _document(
        'demo-bill-internet',
        bill,
        draft,
        _meta(
          'OT-2026-4380',
          ago(12),
          supplier: _suppliers[2],
          dueOn: inDays(10),
        ),
        [_bought(1, 'Internet and phone, month', 4790, 20)],
      ),
      'demo-supplier-telecom',
    )
    // Captured by Chiara and sent for approval: the owner decides it.
    ..addPendingBill(
      _document(
        'demo-bill-catering',
        bill,
        draft,
        _meta('TR-3321', ago(2), dueOn: inDays(30)),
        [_bought(1, 'Catering, open evening', 22000, 10)],
      ),
    );
}

/// A receipt Chiara paid out of pocket, approved and reimbursed in full:
/// the end of a member's expense claim.
void _seedReimbursedReceipt(FakePurchaseRepository purchases, DateTime today) {
  final paidOn = today.subtract(const Duration(days: 8));
  final receipt = _document(
    'demo-receipt-ink',
    PurchaseKind.memberReceipt,
    PurchaseState.approved,
    _meta('', today.subtract(const Duration(days: 14))),
    [_bought(1, 'Printer ink', 4200, 20)],
  );
  purchases
    ..add(receipt)
    ..payables.add(
      PayableRow(
        obligation: PurchaseObligation(
          id: 'demo-claim-ink',
          purchaseId: receipt.summary.id,
          creditorKind: CreditorKind.member,
          creditorId: 'member-3',
          amountCents: 4200,
          currency: 'EUR',
          paidCents: 4200,
          appliedCents: 0,
          remainingCents: 0,
          allocations: [
            SettlementAllocation(
              id: 'demo-allocation-ink',
              isReversal: false,
              amountCents: 4200,
              method: 'bank_transfer',
              reference: 'Reimbursement, printer ink',
              paidOn: paidOn,
            ),
          ],
        ),
        purchase: receipt.summary,
      ),
    )
    ..claimRates['demo-receipt-ink'] = 20;
}

/// An offset settles an invoice: a standing partial until the last cent.
void _settle(
  FakeMoneyRepository money,
  String invoiceId,
  int cents,
  DateTime now,
) {
  final invoice = money.invoices.where((i) => i.id == invoiceId).firstOrNull;
  if (invoice == null) return;
  final paid = (money.invoiceMatchesStore[invoiceId]?.paidCents ?? 0) + cents;
  money.invoiceMatchesStore[invoiceId] = InvoiceMatch(
    invoiceId: invoiceId,
    paidCents: paid,
    resolution: paid >= invoice.totalCents ? 'exact' : 'under_accepted',
    note: paid >= invoice.totalCents
        ? ''
        : 'part offset against an expense claim',
    matchedAt: now,
    byName: 'Offset',
  );
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 — one seeded year every financial exporter is driven over: INV-1 at
// 20 % and 5.5 % with a netted payment (40.00) and a netted expense
// (30.00), INV-2 part-paid, INV-3 written off, a credit note on INV-2, a
// 2024 expense credit and a 2025 confirmed repartition (both outside the
// export year).
import 'package:deskilo/features/money/domain/expense_repartition.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';

const seededCompany = InvoiceParty(
  name: 'Cowork',
  country: 'FR',
  legalId: '812 345 678',
  vatRegime: 'standard',
);

Invoice _inv(
  String n,
  DateTime at,
  List<InvoiceLine> lines,
  int total,
  List<InvoiceVatTotal> vat, {
  String replaces = '',
}) => Invoice(
  id: 'id-$n',
  workspaceId: 'ws',
  memberId: 'm1',
  number: n,
  issuedAt: at,
  period: '2026-02',
  title: 'T $n',
  lines: lines,
  totalCents: total,
  currency: 'EUR',
  memberName: 'Ana',
  memberAddress: 'a',
  workspaceName: 'w',
  workspaceAddress: 'a',
  issuerName: 'Flo',
  signature: 'f' * 64,
  sellerParty: seededCompany,
  vatTotals: vat,
  replacesNumber: replaces,
);

InvoiceVatTotal _vt(double p, int g, int n, int v) => InvoiceVatTotal(
  percent: p,
  category: 'S',
  grossCents: g,
  netCents: n,
  vatCents: v,
);

class SeededExportYear {
  SeededExportYear._();

  static final inv1 = _inv(
    'INV-1',
    DateTime(2026, 3, 5),
    const [
      InvoiceLine(
        kind: 'subscription',
        label: '100',
        amountCents: 12000,
        vatPercent: 20,
      ),
      InvoiceLine(
        kind: 'accessories',
        label: 'x',
        amountCents: 10550,
        vatPercent: 5.5,
      ),
      InvoiceLine(kind: 'payment', label: 'Virement', amountCents: -4000),
      InvoiceLine(kind: 'expense', label: 'Taxi refund', amountCents: -3000),
    ],
    15550,
    [_vt(20, 12000, 10000, 2000), _vt(5.5, 10550, 10000, 550)],
  );
  static final inv2 = _inv(
    'INV-2',
    DateTime(2026, 4, 5),
    const [
      InvoiceLine(
        kind: 'subscription',
        label: '100',
        amountCents: 20000,
        vatPercent: 20,
      ),
    ],
    20000,
    [_vt(20, 20000, 16667, 3333)],
  );
  static final inv3 = _inv(
    'INV-3',
    DateTime(2026, 5, 5),
    const [
      InvoiceLine(
        kind: 'subscription',
        label: '100',
        amountCents: 10000,
        vatPercent: 20,
      ),
    ],
    10000,
    [_vt(20, 10000, 8333, 1667)],
  );
  static final creditNote = _inv(
    'CN-1',
    DateTime(2026, 6, 5),
    const [
      InvoiceLine(
        kind: 'adjustment',
        label: 'credit',
        amountCents: -5000,
        vatPercent: 20,
      ),
    ],
    -5000,
    [_vt(20, -5000, -4167, -833)],
    replaces: 'INV-2',
  );

  static List<Invoice> get invoices => [inv1, inv2, inv3, creditNote];

  static Map<String, InvoiceMatch> get matches => {
    inv1.id: InvoiceMatch(
      invoiceId: inv1.id,
      paidCents: 15550,
      resolution: 'paid',
      matchedAt: DateTime(2026, 3, 20),
    ),
    inv2.id: InvoiceMatch(
      invoiceId: inv2.id,
      paidCents: 12000,
      resolution: 'partial',
      matchedAt: DateTime(2026, 4, 20),
    ),
    inv3.id: InvoiceMatch(
      invoiceId: inv3.id,
      paidCents: 6000,
      resolution: 'writeoff',
      matchedAt: DateTime(2026, 5, 20),
      writeoffAt: DateTime(2026, 5, 25),
    ),
  };

  static LedgerEntry _le(
    String id,
    DateTime on,
    int cents,
    LedgerCategory cat,
    String period,
  ) => LedgerEntry(
    id: id,
    memberId: 'm1',
    kind: LedgerKind.credit,
    category: cat,
    amountCents: cents,
    description: 'd $id',
    period: period,
    createdAt: on,
  );

  static List<LedgerEntry> get ledger => [
    _le(
      'L-exp-2026',
      DateTime(2026, 2, 10),
      3000,
      LedgerCategory.expense,
      '2026-02',
    ),
    _le(
      'L-pay-2026',
      DateTime(2026, 2, 12),
      4000,
      LedgerCategory.payment,
      '2026-02',
    ),
    _le(
      'L-exp-2024',
      DateTime(2024, 5, 10),
      2000,
      LedgerCategory.expense,
      '2024-05',
    ),
  ];

  static List<ExpenseRepartition> get repartitions => [
    ExpenseRepartition(
      id: 'R-2025',
      title: 'Cleaning 2025',
      amountCents: 7000,
      method: RepartitionMethod.equal,
      period: '2025-03',
      shares: const [],
      status: 'confirmed',
      createdAt: DateTime(2025, 3, 3),
    ),
  ];
}

// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show PostingJournal;
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';

/// #3470 -- one journal: the code the books know it by, and its label. Plain
/// strings, so the journals travel without the jurisdiction contract.
class FecJournal {
  const FecJournal({required this.code, required this.label});

  final String code;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is FecJournal && other.code == code && other.label == label;

  @override
  int get hashCode => Object.hash(code, label);
}

/// The journals supplied to a FEC: code and label per role.
/// The host resolves its declaration and the business's stored values.
class FecJournals {
  const FecJournals({
    required this.sales,
    required this.bank,
    required this.purchases,
    required this.misc,
  });

  /// #3470 -- the roles, in the order a form and a stored value list them.
  static const roles = ['sales', 'bank', 'purchases', 'misc'];

  /// The business's journals as stored (`{role: {code, label}}`), or null
  /// when nothing is stored or the value is not whole: then the defaults
  /// apply. A stored value was refused whole on its way in, never cleaned.
  static FecJournals? fromJson(Object? json) {
    if (json is! Map || json.isEmpty) return null;
    FecJournal? of(String role) => switch (json[role]) {
      {'code': final String code, 'label': final String label} =>
        FecJournal(code: code, label: label),
      _ => null,
    };
    final [sales, bank, purchases, misc] = [for (final r in roles) of(r)];
    if (sales == null || bank == null || purchases == null || misc == null) {
      return null;
    }
    return FecJournals(
      sales: sales,
      bank: bank,
      purchases: purchases,
      misc: misc,
    );
  }

  Map<String, Object?> toJson() => {
    for (final (role, j) in byRole) role: {'code': j.code, 'label': j.label},
  };

  /// The four journals with their role, in [roles] order.
  List<(String, FecJournal)> get byRole => [
    ('sales', sales),
    ('bank', bank),
    ('purchases', purchases),
    ('misc', misc),
  ];

  final FecJournal sales;
  final FecJournal bank;
  final FecJournal purchases;
  final FecJournal misc;

  @override
  bool operator ==(Object other) =>
      other is FecJournals &&
      other.sales == sales &&
      other.bank == bank &&
      other.purchases == purchases &&
      other.misc == misc;

  @override
  int get hashCode => Object.hash(sales, bank, purchases, misc);
}

/// The accounts a FEC cannot be written without. Defaults follow the
/// French *plan comptable général*; an accountant using a different chart
/// corrects them at export time — which is also the moment the exporter
/// shows what it is about to book, rather than inventing it silently.
///
/// #2481 -- a default is a row of the tax reference store (the French chart
/// and the `fec` row), read from the supplied [reference] snapshot.
class FecAccounts {
  const FecAccounts({
    String? customers,
    String? revenue,
    String? bank,
    String? vat,
    String? expenses,
    String? vatPending,
    String? writeOff,
    required this.chartCountry,
    required this.journals,
    required this.reference,
  }) : _givenCustomers = customers,
       _givenRevenue = revenue,
       _givenBank = bank,
       _givenVat = vat,
       _givenExpenses = expenses,
       _givenVatPending = vatPending,
       _givenWriteOff = writeOff;

  final TaxReferenceSet reference;
  final String? _givenCustomers;
  final String? _givenRevenue;
  final String? _givenBank;
  final String? _givenVat;
  final String? _givenExpenses;
  final String? _givenVatPending;
  final String? _givenWriteOff;
  /// The supplied chart country and business journals of this export.
  final String chartCountry;
  final FecJournals journals;

  /// #3470 -- these accounts, writing the business's [journals].
  FecAccounts withJournals(FecJournals journals) => FecAccounts(
    customers: _givenCustomers,
    revenue: _givenRevenue,
    bank: _givenBank,
    vat: _givenVat,
    expenses: _givenExpenses,
    vatPending: _givenVatPending,
    writeOff: _givenWriteOff,
    chartCountry: chartCountry,
    journals: journals,
    reference: reference,
  );

  String _default(String format, String role) =>
      reference.accountOf(format, role, chartCountry);

  /// PCG 411 — Clients (the receivable).
  String get customers => _givenCustomers ?? _default('coa', 'customers');

  /// PCG 706 — Prestations de services (what a coworking sells).
  String get revenue => _givenRevenue ?? _default('coa', 'revenue');

  /// PCG 512 — Banques (where the money lands).
  String get bank => _givenBank ?? _default('coa', 'bank');

  /// PCG 44571 — TVA collectée. Only used when the invoice carries VAT
  /// (0072); a workspace that charges none never books to it.
  String get vat => _givenVat ?? _default('coa', 'vat');

  /// #936 — what the workspace spends: reimbursed expenses and shared
  /// costs. 606 "achats non stockés" by default; the accountant's chart
  /// wins at export time like the others.
  String get expenses => _givenExpenses ?? _default('coa', 'expenses');

  /// #2355 — PCG 44574, TVA collectée en attente: the VAT an invoice
  /// carries but whose tax point has not come yet (services on receipts,
  /// a service month still to come). It moves to [vat] on the tax point.
  String get vatPending => _givenVatPending ?? _default('fec', 'vat_pending');

  /// #2365 — PCG 654, pertes sur créances irrécouvrables: what the owner
  /// gave up of an invoice, booked at the gross amount it was still owed.
  String get writeOff => _givenWriteOff ?? _default('fec', 'write_off');
}

/// The business's journal of the posting engine's [journal] (its own
/// `PostingJournal.code` is the engine's internal key).
FecJournal journalFor(FecJournals journals, PostingJournal journal) =>
    switch (journal) {
      PostingJournal.sales => journals.sales,
      PostingJournal.bank => journals.bank,
      PostingJournal.purchases => journals.purchases,
      PostingJournal.other => journals.misc,
    };


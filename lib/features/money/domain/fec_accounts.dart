// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart'
    show AccountingJournal;
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import '../../../core/jurisdiction/installed_accounting_formats.dart';
import '../../../core/vat/tax_reference_active.dart';

/// #3429 -- the journals a FEC writes, as the installed FEC format declares
/// them (`AccountingFormatContribution.journals`): code and label per role.
class FecJournals {
  const FecJournals({
    required this.sales,
    required this.bank,
    required this.purchases,
    required this.misc,
  });

  /// The journals of the installed FEC declaration.
  factory FecJournals.installed() {
    final declared = accountingFormatOf('fec').journals;
    AccountingJournal of(String role) =>
        declared[role] ??
        (throw StateError('the FEC declaration has no $role journal'));
    return FecJournals(
      sales: of('sales'),
      bank: of('bank'),
      purchases: of('purchases'),
      misc: of('misc'),
    );
  }

  final AccountingJournal sales;
  final AccountingJournal bank;
  final AccountingJournal purchases;
  final AccountingJournal misc;
}

/// The accounts a FEC cannot be written without. Defaults follow the
/// French *plan comptable général*; an accountant using a different chart
/// corrects them at export time — which is also the moment the exporter
/// shows what it is about to book, rather than inventing it silently.
///
/// #2481 -- a default is a row of the tax reference store (the French chart
/// and the `fec` row), read when asked; [reference] is the snapshot to read
/// from, the installed one when null.
class FecAccounts {
  const FecAccounts({
    String? customers,
    String? revenue,
    String? bank,
    String? vat,
    String? expenses,
    String? vatPending,
    String? writeOff,
    String? chartCountry,
    FecJournals? journals,
    this.reference,
  }) : _givenCustomers = customers,
       _givenRevenue = revenue,
       _givenBank = bank,
       _givenVat = vat,
       _givenExpenses = expenses,
       _givenVatPending = vatPending,
       _givenWriteOff = writeOff,
       _givenCountry = chartCountry,
       _givenJournals = journals;

  final TaxReferenceSet? reference;
  final String? _givenCustomers;
  final String? _givenRevenue;
  final String? _givenBank;
  final String? _givenVat;
  final String? _givenExpenses;
  final String? _givenVatPending;
  final String? _givenWriteOff;
  final String? _givenCountry;
  final FecJournals? _givenJournals;

  /// #3429 -- the journals the FEC writes: given, else the installed FEC
  /// declaration's.
  FecJournals get journals => _givenJournals ?? FecJournals.installed();

  /// #3429 -- the country whose chart the defaults are rows of: given, else
  /// what the installed FEC format declares (the plan comptable général).
  String get chartCountry =>
      _givenCountry ?? accountingFormatOf('fec').chartCountry;

  String _default(String format, String role) =>
      (reference ?? ActiveTaxReference.current).accountOf(format, role, chartCountry);

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

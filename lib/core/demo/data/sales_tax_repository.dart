// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart'
    show VatComponent;
import '../../../features/money/domain/sales_tax_repository.dart';
import '../../../features/money/domain/sales_tax_return.dart';
import '../../../features/money/domain/tax_exemption_certificate.dart';

/// #2362 -- the sales-tax summary and the certificates in memory. The demo
/// issues no sales-tax invoice, so it states nothing unless a test seeds
/// [rows] or a business states its own ([statedFor]).
class FakeSalesTaxRepository implements SalesTaxRepository {
  FakeSalesTaxRepository({this.statedFor});

  final List<SalesTaxReturnRow> rows = [];

  /// #4009 -- a business that states its own return (the Demo's New York):
  /// the rows of its period, or null when the business states nothing and
  /// [rows] answer.
  final List<SalesTaxReturnRow>? Function(
    String workspaceId,
    DateTime start,
    DateTime end,
  )?
  statedFor;

  /// memberId -> its certificates.
  final Map<String, List<TaxExemptionCertificate>> certificates = {};
  int _next = 0;

  @override
  Future<List<SalesTaxReturnRow>> fetchReturn(
    String workspaceId, {
    required DateTime start,
    required DateTime end,
  }) async => List.of(statedFor?.call(workspaceId, start, end) ?? rows);

  @override
  Future<List<TaxExemptionCertificate>> fetchCertificates(
    String memberId,
  ) async => List.of(certificates[memberId] ?? const []);

  @override
  Future<void> saveCertificate(TaxExemptionCertificateDraft draft) async {
    (certificates[draft.memberId] ??= []).insert(
      0,
      TaxExemptionCertificate(
        id: 'cert-${_next++}',
        kind: draft.kind,
        state: draft.state.toUpperCase(),
        number: draft.number.trim(),
        validFrom: isoDay(draft.validFrom),
        validTo: draft.validTo == null ? null : isoDay(draft.validTo!),
      ),
    );
  }

  @override
  Future<void> endCertificate(String id, DateTime on) async {
    for (final list in certificates.values) {
      final i = list.indexWhere((c) => c.id == id);
      if (i < 0) continue;
      final c = list[i];
      final end = isoDay(on).compareTo(c.validFrom) < 0
          ? c.validFrom
          : isoDay(on);
      list[i] = TaxExemptionCertificate(
        id: c.id,
        kind: c.kind,
        state: c.state,
        number: c.number,
        validFrom: c.validFrom,
        validTo: end,
      );
    }
  }
}

typedef _Entry = ({String id, InvoiceVatTotal total});

int _base(Iterable<_Entry> v) => v.fold(0, (a, e) => a + e.total.netCents);

int _count(Iterable<_Entry> v) => {for (final e in v) e.id}.length;

SalesTaxReturnRow _plain(String state, SalesTaxLine line, List<_Entry> v) =>
    SalesTaxReturnRow(
      state: state,
      line: line,
      baseCents: _base(v),
      taxCents: 0,
      invoiceCount: _count(v),
    );

/// The taxed sales of a state and the tax collected on them, then the tax of
/// each jurisdiction its invoices froze, in the order of its name.
List<SalesTaxReturnRow> _taxedRows(String state, List<_Entry> taxed) {
  final byJurisdiction =
      <(String, String, double), List<({String id, VatComponent c})>>{};
  for (final e in taxed) {
    for (final c in e.total.components) {
      (byJurisdiction[(c.level, c.name, c.percent)] ??= []).add((
        id: e.id,
        c: c,
      ));
    }
  }
  final keys = byJurisdiction.keys.toList()
    ..sort((a, b) => a.$2.compareTo(b.$2));
  return [
    SalesTaxReturnRow(
      state: state,
      line: SalesTaxLine.taxable,
      baseCents: _base(taxed),
      taxCents: taxed.fold(0, (a, e) => a + e.total.vatCents),
      invoiceCount: _count(taxed),
    ),
    for (final key in keys)
      SalesTaxReturnRow(
        state: state,
        line: SalesTaxLine.tax,
        level: key.$1,
        name: key.$2,
        percent: key.$3,
        baseCents: byJurisdiction[key]!.fold(0, (a, e) => a + e.c.baseCents),
        taxCents: byJurisdiction[key]!.fold(0, (a, e) => a + e.c.taxCents),
        invoiceCount: {for (final e in byJurisdiction[key]!) e.id}.length,
      ),
  ];
}

/// One state's rows: taxed, then exempt by statute, by certificate, then
/// outside the tax; a kind none of the invoices froze has no row.
List<SalesTaxReturnRow> _stateRows(String state, List<_Entry> mine) {
  List<_Entry> of(String category, [String basis = '']) => [
    for (final e in mine)
      if (e.total.category == category &&
          (basis.isEmpty ||
              (e.total.exemptionBasis.isEmpty
                      ? 'statute'
                      : e.total.exemptionBasis) ==
                  basis))
        e,
  ];
  final taxed = of('S');
  final statute = of('E', 'statute');
  final certificate = of('E', 'certificate');
  final outside = of('O');
  return [
    if (taxed.isNotEmpty) ..._taxedRows(state, taxed),
    if (statute.isNotEmpty) _plain(state, SalesTaxLine.exemptStatute, statute),
    if (certificate.isNotEmpty)
      _plain(state, SalesTaxLine.exemptCertificate, certificate),
    if (outside.isNotEmpty) _plain(state, SalesTaxLine.outside, outside),
  ];
}

/// The sales-tax return of `[start, end]` stated from [invoices] as the
/// server's `sales_tax_return` does (0439): the invoices issued in the period
/// and not voided, their totals that froze a jurisdiction, per state the taxed
/// sales with the tax collected, the tax per jurisdiction, what is exempt by
/// statute or by certificate, and what is outside the tax. A period with none
/// states nothing.
List<SalesTaxReturnRow> salesTaxReturnOf(
  Iterable<Invoice> invoices, {
  required DateTime start,
  required DateTime end,
}) {
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
  final entries = <_Entry>[
    for (final i in invoices)
      if (i.voidedAt == null &&
          !day(i.issuedAt).isBefore(day(start)) &&
          !day(i.issuedAt).isAfter(day(end)))
        for (final t in i.vatTotals)
          if (t.isSalesTax) (id: i.id, total: t),
  ];
  final states = {for (final e in entries) e.total.state}.toList()..sort();
  return [
    for (final state in states)
      ..._stateRows(state, [
        for (final e in entries)
          if (e.total.state == state) e,
      ]),
  ];
}

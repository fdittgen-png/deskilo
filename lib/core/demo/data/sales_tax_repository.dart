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
  int base(Iterable<_Entry> v) => v.fold(0, (a, e) => a + e.total.netCents);
  int count(Iterable<_Entry> v) => {for (final e in v) e.id}.length;
  SalesTaxReturnRow plain(
    String state,
    SalesTaxLine line,
    Iterable<_Entry> v,
  ) => SalesTaxReturnRow(
    state: state,
    line: line,
    baseCents: base(v),
    taxCents: 0,
    invoiceCount: count(v),
  );
  final rows = <SalesTaxReturnRow>[];
  final states = {for (final e in entries) e.total.state}.toList()..sort();
  for (final state in states) {
    final mine = [
      for (final e in entries)
        if (e.total.state == state) e,
    ];
    final taxed = mine.where((e) => e.total.category == 'S').toList();
    if (taxed.isNotEmpty) {
      rows.add(
        SalesTaxReturnRow(
          state: state,
          line: SalesTaxLine.taxable,
          baseCents: base(taxed),
          taxCents: taxed.fold(0, (a, e) => a + e.total.vatCents),
          invoiceCount: count(taxed),
        ),
      );
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
      for (final key in keys) {
        final v = byJurisdiction[key]!;
        rows.add(
          SalesTaxReturnRow(
            state: state,
            line: SalesTaxLine.tax,
            level: key.$1,
            name: key.$2,
            percent: key.$3,
            baseCents: v.fold(0, (a, e) => a + e.c.baseCents),
            taxCents: v.fold(0, (a, e) => a + e.c.taxCents),
            invoiceCount: {for (final e in v) e.id}.length,
          ),
        );
      }
    }
    for (final (basis, line) in const [
      ('statute', SalesTaxLine.exemptStatute),
      ('certificate', SalesTaxLine.exemptCertificate),
    ]) {
      final exempt = mine
          .where(
            (e) =>
                e.total.category == 'E' &&
                (e.total.exemptionBasis.isEmpty
                        ? 'statute'
                        : e.total.exemptionBasis) ==
                    basis,
          )
          .toList();
      if (exempt.isNotEmpty) rows.add(plain(state, line, exempt));
    }
    final outside = mine.where((e) => e.total.category == 'O').toList();
    if (outside.isNotEmpty) {
      rows.add(plain(state, SalesTaxLine.outside, outside));
    }
  }
  return rows;
}

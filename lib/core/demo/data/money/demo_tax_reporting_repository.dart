// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/features/money/domain/accounting_view.dart';
import 'package:deskilo/features/money/domain/tax_reporting_repository.dart';
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:deskilo/features/money/domain/vat_period_lock.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/domain/vat_tax_point.dart';

import '../money_repository.dart';

/// #2591 — the demo's VAT rates and returns, answered from one space's
/// in-memory money store ([FakeMoneyRepository]); every other port of that
/// space reads and writes the same store.
class DemoTaxReporting implements TaxReportingRepository {
  DemoTaxReporting(this._m);

  final FakeMoneyRepository _m;

  @override
  Future<List<VatDeclaration>> fetchVatDeclarations(String workspaceId) async =>
      List.of(_m.vatDeclarations);

  /// The return of [start]..[end], filed periods locked (`vat_return_lines`).
  List<VatReturnAmount> _vatReturn(DateTime start, DateTime end) {
    final view = accountingView(_m.invoices, _m.invoiceMatchesStore);
    return vatReturnAmountsOf(
      vatTaxPointLedger(
        view.invoices,
        matches: view.matches,
        instalments: _m.invoiceInstalmentsStore,
        basis: _m.vatReturnBasis,
      ),
      start: start,
      end: end,
      locks: vatPeriodLocksOf(_m.vatDeclarations),
      declared: _m.vatDeclared,
    );
  }

  /// Prepares the period like `save_vat_declaration` (0402/0406) with
  /// the Dart engine the SQL is the twin of.
  @override
  Future<String> saveVatDeclaration({
    required String workspaceId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final existing = _m.vatDeclarations.indexWhere(
      (d) => d.periodStart == periodStart && d.periodEnd == periodEnd,
    );
    if (existing != -1 && _m.vatDeclarations[existing].isFiled) {
      throw StateError('declaration already filed for this period');
    }
    if (vatPeriodLocksOf(
      _m.vatDeclarations,
    ).any((l) => !l.start.isAfter(periodEnd) && !l.end.isBefore(periodStart))) {
      throw StateError('this period overlaps a filed return');
    }
    final amounts = _vatReturn(periodStart, periodEnd);
    final lines = vatReturnLinesOf(amounts, declarations: _m.vatDeclarations);
    final documents = {for (final a in amounts) a.invoiceId};
    final declaration = VatDeclaration(
      id: existing != -1
          ? _m.vatDeclarations[existing].id
          : 'decl-${_m.vatDeclarations.length + 1}',
      workspaceId: workspaceId,
      periodStart: periodStart,
      periodEnd: periodEnd,
      status: 'prepared',
      lines: lines,
      totalNetCents: lines.fold(0, (sum, l) => sum + l.netCents),
      totalVatCents: lines.fold(0, (sum, l) => sum + l.vatCents),
      currency: 'EUR',
      invoiceCount: documents.length,
      createdAt: DateTime.utc(2026, 8, 11),
    );
    if (existing != -1) {
      _m.vatDeclarations[existing] = declaration;
    } else {
      _m.vatDeclarations.add(declaration);
    }
    return declaration.id;
  }

  @override
  Future<void> markVatDeclarationSubmitted({
    required String declarationId,
    required String channel,
    required String receipt,
  }) async {
    final index = _m.vatDeclarations.indexWhere((d) => d.id == declarationId);
    if (index == -1) throw StateError('unknown declaration');
    final d = _m.vatDeclarations[index];
    if (d.isFiled) throw StateError('declaration already filed');
    if (channel != 'manual' && channel != 'export') {
      throw StateError('unknown channel');
    }
    if (receipt.trim().isEmpty) {
      throw StateError('the receipt reference is required');
    }
    if (!d.isPrepared) throw StateError('prepare the return before filing it');
    _m.vatDeclared.addAll(
      vatDeclaredBy(_vatReturn(d.periodStart, d.periodEnd)),
    );
    _m.vatDeclarations[index] = VatDeclaration(
      id: d.id,
      workspaceId: d.workspaceId,
      periodStart: d.periodStart,
      periodEnd: d.periodEnd,
      status: 'filed',
      lines: d.lines,
      totalNetCents: d.totalNetCents,
      totalVatCents: d.totalVatCents,
      currency: d.currency,
      invoiceCount: d.invoiceCount,
      createdAt: d.createdAt,
      submittedAt: DateTime.utc(2026, 8, 11, 12),
      submittedChannel: channel,
      submittedReceipt: receipt.trim(),
      number: 'DECL-2026-${(index + 1).toString().padLeft(4, '0')}',
    );
  }

  @override
  Future<List<VatRate>> fetchVatRates(String workspaceId) async =>
      _m.vatRates.where((r) => r.active).toList()
        ..sort((a, b) => b.percent.compareTo(a.percent));

  @override
  Future<void> setVatRates(String workspaceId, List<VatRate> rates) async {
    // Mirror set_vat_rates' precondition rather than accepting a set the
    // server would reject. An EMPTY set is allowed: that is how VAT is
    // turned back off.
    if (rates.isNotEmpty &&
        rates.where((r) => r.active && r.isDefault).length != 1) {
      throw StateError('exactly one default rate is required');
    }
    _m.vatRates = [
      for (var i = 0; i < rates.length; i++)
        if (rates[i].id.isEmpty)
          VatRate(
            id: 'vat-${i + 1}',
            label: rates[i].label,
            percent: rates[i].percent,
            category: rates[i].category,
            isDefault: rates[i].isDefault,
            active: rates[i].active,
            groupKey: rates[i].groupKey,
            outsideBase: rates[i].outsideBase,
            exemptionReason: rates[i].exemptionReason,
            validFrom: rates[i].validFrom,
            validTo: rates[i].validTo,
            supersedesId: rates[i].supersedesId,
          )
        else
          rates[i],
    ];
  }
}

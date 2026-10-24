// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C4 — Me › Finances: the filters the overview's own facts support,
// and nothing more. The source/workspace is the issuing workspace; the
// period is the year a document was issued, on the device's calendar; the
// type is an invoice or a credit note, by the same rule the workspace's
// documents follow (a negative face value). No filter invents a deadline
// or a state the server did not derive.
import 'finance_overview.dart';

/// The kind of document a row is.
enum FinanceDocType {
  all,
  invoice,
  creditNote;

  bool accepts(FinanceInvoice document) => switch (this) {
    FinanceDocType.all => true,
    FinanceDocType.invoice => !document.isCreditNote,
    FinanceDocType.creditNote => document.isCreditNote,
  };
}

/// What Me › Finances is narrowed to: one workspace or all of them, one
/// issue year or all of them, one document type or both.
class FinanceFilter {
  const FinanceFilter({
    this.workspaceId,
    this.year,
    this.type = FinanceDocType.all,
  });

  /// Only this workspace's documents; every workspace when null.
  final String? workspaceId;

  /// Only documents issued in this (local) year; every year when null.
  final int? year;

  final FinanceDocType type;

  /// Whether a dated record (a payment, a reminder) falls in the period.
  bool inPeriod(DateTime at) => year == null || at.toLocal().year == year;

  /// The invoices this filter keeps, with the reminders of those invoices.
  FinanceOverview apply(FinanceOverview overview) => overview
      .inWorkspace(workspaceId)
      .where((i) => inPeriod(i.issuedAt) && type.accepts(i));

  FinanceFilter copyWith({
    String? Function()? workspaceId,
    int? Function()? year,
    FinanceDocType? type,
  }) => FinanceFilter(
    workspaceId: workspaceId == null ? this.workspaceId : workspaceId(),
    year: year == null ? this.year : year(),
    type: type ?? this.type,
  );
}

/// The issue years present in [overview], newest first: the only periods
/// worth offering.
List<int> financeYears(FinanceOverview overview) =>
    {for (final i in overview.invoices) i.issuedAt.toLocal().year}.toList()
      ..sort((a, b) => b.compareTo(a));

/// [invoices] newest first; the qualified id (workspace, then document)
/// breaks a tie, so two hosts' equal local ids never swap places.
List<FinanceInvoice> newestFirst(Iterable<FinanceInvoice> invoices) =>
    [...invoices]..sort((a, b) {
      final byDate = b.issuedAt.compareTo(a.issuedAt);
      if (byDate != 0) return byDate;
      final byWorkspace = a.workspaceId.compareTo(b.workspaceId);
      return byWorkspace != 0 ? byWorkspace : a.id.compareTo(b.id);
    });

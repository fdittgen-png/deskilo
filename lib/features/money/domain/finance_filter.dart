// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C4 — Me › Finances: the filters the overview's own facts support,
// and nothing more. The source/workspace is the issuing workspace; the
// period is the year a document was issued, on the calendar of the business that issued it (never
// the device's: the same document reads the same year on every phone); the
// type is an invoice or a credit note, by the same rule the workspace's
// documents follow (a negative face value). No filter invents a deadline
// or a state the server did not derive.
import 'package:meta/meta.dart';

import '../../../core/time/business_day.dart';
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

  /// Only documents issued in this year, read on the issuing business's calendar; every year when
  /// null.
  final int? year;

  final FinanceDocType type;

  /// Whether a dated record (a document, a payment, a reminder) falls in the period: its year on
  /// the calendar of the business it belongs to ([timezone], the business's IANA zone; the UTC
  /// year when none is known).
  bool inPeriod(DateTime at, {String? timezone}) =>
      year == null || financeYearOf(at, timezone) == year;

  /// The invoices this filter keeps, with the reminders of those invoices.
  FinanceOverview apply(FinanceOverview overview) => overview
      .inWorkspace(workspaceId)
      .where((i) => inPeriod(i.issuedAt, timezone: i.timezone) && type.accepts(i));

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

/// The year of [at] on the calendar of the business whose zone is [timezone].
@visibleForTesting
int financeYearOf(DateTime at, String? timezone) => businessDateOf(at, timezone).year;

/// The business zone of each workspace (by network id) the overview's invoices come from, for the
/// records that name a workspace but carry no zone of their own (a payment).
Map<String, String?> financeZones(FinanceOverview overview) => {
  for (final i in overview.invoices)
    if (i.timezone != null) i.networkId: i.timezone,
};

/// The issue years present in [overview], newest first, each read on its issuing business's
/// calendar: the only periods worth offering.
List<int> financeYears(FinanceOverview overview) =>
    {for (final i in overview.invoices) financeYearOf(i.issuedAt, i.timezone)}.toList()
      ..sort((a, b) => b.compareTo(a));

/// [invoices] newest first; the qualified id (workspace, then document)
/// breaks a tie, so two hosts' equal local ids never swap places.
List<FinanceInvoice> newestFirst(Iterable<FinanceInvoice> invoices) =>
    [...invoices]..sort((a, b) {
      final byDate = b.issuedAt.compareTo(a.issuedAt);
      if (byDate != 0) return byDate;
      final byWorkspace = a.networkId.compareTo(b.networkId);
      return byWorkspace != 0 ? byWorkspace : a.id.compareTo(b.id);
    });

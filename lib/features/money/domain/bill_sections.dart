// SPDX-License-Identifier: MIT
import 'package:intl/intl.dart';

import '../../events/domain/workspace_event.dart';
import 'ledger_entry.dart';

/// One pending money event shown as an open position on the bill (#132):
/// submitted but not yet validated, so it is not part of the statement.
class OpenPosition {
  const OpenPosition(this.event);

  final WorkspaceEvent event;

  int get amountCents => (event.payload['amount_cents'] as num?)?.toInt() ?? 0;

  /// Payments and expenses become credits once confirmed; service charges
  /// become charges.
  bool get isCredit =>
      event.type == EventType.payment || event.type == EventType.expense;
}

/// The grouped sections of one member's monthly bill (#132, ADR 0008).
/// Plain Dart on purpose: the on-screen bill and the PDF export share this
/// grouping, so section membership is decided exactly once.
class BillSections {
  const BillSections({
    required this.serviceEntries,
    required this.packageEntries,
    required this.openPositions,
    required this.creditEntries,
  });

  /// Confirmed service consumptions of the period (name ×qty descriptions).
  final List<LedgerEntry> serviceEntries;

  /// Day packages bought this period (migration 0042) — charge lines.
  final List<LedgerEntry> packageEntries;

  /// My pending money events that would land on this period once confirmed.
  final List<OpenPosition> openPositions;

  /// Confirmed credits of the period: payments, expense reimbursements and
  /// crediting adjustments.
  final List<LedgerEntry> creditEntries;

  int get servicesTotalCents =>
      serviceEntries.fold(0, (sum, e) => sum + e.amountCents);
}

/// The current month's period key ('yyyy-MM') — where payments/expenses
/// post when confirmed right now (the RPCs book to now()'s period). The
/// ONE definition; money_providers re-exports it (a `billNowPeriod` twin
/// used to live here).
String currentPeriod() => DateFormat('yyyy-MM').format(DateTime.now());

/// Groups [ledger] entries and [pendingEvents] into the sections of
/// [memberId]'s bill for [period] ('yyyy-MM').
///
/// Section rules:
///  * services: confirmed ledger charges of category `service` booked to
///    [period];
///  * open positions: MY pending events that carry money — service charges
///    whose payload period is [period]; payments and expenses only while
///    [period] is [nowPeriod], because on confirmation they post to the
///    then-current period (migrations 0008/0009/0016);
///  * credits: confirmed ledger credits (payment / expense / adjustment)
///    booked to [period].
BillSections buildBillSections({
  required String period,
  required String memberId,
  required List<LedgerEntry> ledger,
  required List<WorkspaceEvent> pendingEvents,
  String? nowPeriod,
}) {
  final now = nowPeriod ?? currentPeriod();

  final services = [
    for (final entry in ledger)
      if (entry.period == period &&
          entry.kind == LedgerKind.charge &&
          entry.category == LedgerCategory.service)
        entry,
  ];

  final packages = [
    for (final entry in ledger)
      if (entry.period == period &&
          entry.kind == LedgerKind.charge &&
          entry.category == LedgerCategory.package)
        entry,
  ];

  final credits = [
    for (final entry in ledger)
      if (entry.period == period &&
          entry.kind == LedgerKind.credit &&
          (entry.category == LedgerCategory.payment ||
              entry.category == LedgerCategory.expense ||
              entry.category == LedgerCategory.adjustment))
        entry,
  ];

  final open = [
    for (final event in pendingEvents)
      if (event.isPending &&
          event.subjectMemberId == memberId &&
          switch (event.type) {
            EventType.serviceCharge => event.payload['period'] == period,
            EventType.payment || EventType.expense => period == now,
            _ => false,
          })
        OpenPosition(event),
  ];

  return BillSections(
    serviceEntries: services,
    packageEntries: packages,
    openPositions: open,
    creditEntries: credits,
  );
}

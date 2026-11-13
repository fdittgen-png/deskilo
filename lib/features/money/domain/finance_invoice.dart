// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › Finances: one of MY invoices as `my_finance_overview` answers it
// (0380, 0736, 0755), and where it stands. Split from `finance_overview.dart`,
// which re-exports it.

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// Where one of MY invoices stands (the 0067/0068 lifecycle, as the server
/// derives it).
enum FinanceState {
  open('open'),
  awaitingValidation('awaiting_validation'),
  partiallyPaid('partially_paid'),
  paid('paid'),
  refunded('refunded'),
  closed('closed');

  const FinanceState(this.wire);
  final String wire;

  static FinanceState fromWire(Object? wire) =>
      values.where((s) => s.wire == wire).firstOrNull ?? FinanceState.open;

  /// Still open: not settled yet (fully or in part).
  bool get owed => this == open || this == awaitingValidation || this == partiallyPaid;

  /// #3682 — still to pay. A payment being validated (0380: the business
  /// matched my payment, its validators have not confirmed it yet) is paid
  /// on my side: open, but neither to pay nor ever late.
  bool get toPay => this == open || this == partiallyPaid;
}

class FinanceInvoice {
  const FinanceInvoice({
    required this.id,
    required this.workspaceId,
    required this.workspaceName,
    required this.number,
    required this.issuedAt,
    required this.totalCents,
    required this.paidCents,
    required this.currency,
    required this.state,
    this.dueOn,
    this.reminderCount = 0,
    this.lastReminderAt,
    this.timezone,
    this.stillDueCents,
    this.awaitingCents,
  });

  final String id, workspaceId, workspaceName, number, currency;

  /// #3659 — the issuing business's IANA zone (0736); null when unnamed.
  final String? timezone;
  final DateTime issuedAt;
  final DateTime? dueOn, lastReminderAt;
  final int totalCents, paidCents, reminderCount;
  final FinanceState state;

  /// #3877 (0755) — the server's own still-due and the parts of a payment
  /// that wait for approval; null from a host that does not answer them.
  final int? stillDueCents, awaitingCents;

  /// What remains to pay: the server's still-due while the invoice is open
  /// (#3877); from a host without it, the whole face value until a payment
  /// is matched and the rest after a partial one. Nothing once settled.
  int get remainingCents => !state.owed
      ? 0
      : stillDueCents ??
          switch (state) {
            FinanceState.partiallyPaid => totalCents - paidCents,
            _ => totalCents,
          };

  /// What I paid that the business has not confirmed yet: the parts awaiting
  /// approval (#3877); from a host without them, the whole open amount of an
  /// invoice awaiting validation.
  int get beingValidatedCents =>
      awaitingCents ?? (state == FinanceState.awaitingValidation ? remainingCents : 0);

  /// Still to pay (#3682): what remains once the parts being validated are
  /// counted as paid; a host without the figures says it by the state.
  bool get toPay => stillDueCents == null ? state.toPay : state.owed && stillDueCents! > 0;

  /// A credit note gives money back: its face value is negative, the same
  /// rule the workspace's own documents follow (`Invoice.isCreditNote`).
  bool get isCreditNote => totalCents < 0;

  factory FinanceInvoice.fromJson(Map<String, dynamic> j) {
    final r = JsonReader(j, context: 'finance_invoice');
    return FinanceInvoice(
      id: r.string('id'),
      workspaceId: r.string('workspace_id'),
      workspaceName: r.stringOr('workspace_name'),
      number: r.stringOr('number'),
      issuedAt: r.dateTime('issued_at'),
      dueOn: r.dateTimeOrNull('due_on'),
      totalCents: r.intOrNull('total_cents') ?? 0,
      paidCents: r.intOrNull('paid_cents') ?? 0,
      // Required (#3599): the column is not null, and an amount whose
      // currency is unknown must fail to read, never read as another one.
      currency: r.string('currency'),
      state: FinanceState.fromWire(r.json['state']),
      reminderCount: r.intOrNull('reminder_count') ?? 0,
      lastReminderAt: r.dateTimeOrNull('last_reminder_at'),
      timezone: r.stringOrNull('workspace_timezone'),
      stillDueCents: r.intOrNull('still_due_cents'),
      awaitingCents: r.intOrNull('awaiting_cents'),
    );
  }
}

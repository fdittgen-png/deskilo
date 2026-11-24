// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › Finances: one of MY invoices as `my_finance_overview` answers it
// (0380, 0736, 0755, 0911), and where it stands. Split from `finance_overview.dart`,
// which re-exports it.

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../core/backend/operation_context.dart' show WorkspaceTarget;

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

/// #4418 -- where the online payment of an open claim stands, decoded once
/// from `claim_payment_state` (0810, 0814).
enum PaymentClaimState {
  ready('ready'),
  unavailable('unavailable'),
  awaitingProvider('awaiting_provider'),
  changed('changed'),
  expired('expired'),
  failed('failed'),
  reversed('reversed'),
  withdrawn('withdrawn'),

  /// A state a newer server sent and this app does not know (#3730): no
  /// word is said about it.
  unknown('');

  const PaymentClaimState(this.wire);

  /// The name the server sends.
  final String wire;

  /// [raw] as this app reads it; a value it does not know is [unknown].
  static PaymentClaimState fromWire(String? raw) {
    for (final s in values) {
      if (s != unknown && s.wire == raw) return s;
    }
    return unknown;
  }
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
    this.installationId,
    this.dueOn,
    this.reminderCount = 0,
    this.lastReminderAt,
    this.timezone,
    this.stillDueCents,
    this.awaitingCents,
    this.period,
    this.inPayment = false,
    this.claimPaymentId,
    this.claimCanContinue,
    this.claimPaymentState,
    this.claimEventId,
    this.claimHandedAt,
    this.claimSettling = false,
    this.paymentReceived = false,
    this.payable = false,
    this.financialSubjectId,
    this.billingOnly = false,
  });

  final String id, workspaceId, workspaceName, number, currency;

  /// Stamped by the verified reader, never trusted from the row payload.
  final String? installationId;
  WorkspaceTarget? get target => installationId == null ? null
      : WorkspaceTarget.local(installationId: installationId!, workspaceId: workspaceId);
  String get networkId => target?.networkId ?? workspaceId;

  FinanceInvoice onInstallation(String installationId) => FinanceInvoice(
    installationId: installationId,
    id: id,
    workspaceId: workspaceId,
    workspaceName: workspaceName,
    number: number,
    issuedAt: issuedAt,
    totalCents: totalCents,
    paidCents: paidCents,
    currency: currency,
    state: state,
    dueOn: dueOn,
    reminderCount: reminderCount,
    lastReminderAt: lastReminderAt,
    timezone: timezone,
    stillDueCents: stillDueCents,
    awaitingCents: awaitingCents,
    period: period,
    inPayment: inPayment,
    claimPaymentId: claimPaymentId,
    claimCanContinue: claimCanContinue,
    claimPaymentState: claimPaymentState,
    claimEventId: claimEventId,
    claimHandedAt: claimHandedAt,
    claimSettling: claimSettling,
    paymentReceived: paymentReceived,
    payable: payable,
    financialSubjectId: financialSubjectId,
    billingOnly: billingOnly,
  );

  /// #4164 B2 (0911) — the financial subject this invoice is owed by: the
  /// seller-local `members.id`. Two debtors of one seller and currency are two
  /// subjects; null from a host that does not answer it (the v1 reader).
  final String? financialSubjectId;

  /// #4164 B2 (0911) — read through a billing-access grant (`access:
  /// billing_grant`), not as the account's own membership. These documents
  /// are shown apart and never counted with what I owe as a member.
  final bool billingOnly;

  /// #3659 — the issuing business's IANA zone (0736); null when unnamed.
  final String? timezone;
  final DateTime issuedAt;
  final DateTime? dueOn, lastReminderAt;
  final int totalCents, paidCents, reminderCount;
  final FinanceState state;

  /// #3877 (0755) — the server's own still-due and the parts of a payment
  /// that wait for approval; null from a host that does not answer them.
  final int? stillDueCents, awaitingCents;

  /// #3556 (0805) — the month the invoice is of (`yyyy-MM`); a payment that
  /// names invoices is of their month. Null from a host that does not say.
  final String? period;

  /// #4165 — an invoice without a month (a standalone customer invoice),
  /// owed by a financial subject the host names. A host that names no
  /// subject (the v1 reader) cannot say it is paid as one: it stays
  /// unselectable, as any invoice whose month is not known.
  bool get isStandalone => period == null && financialSubjectId != null;

  /// #3556 (0797) — the invoice is in a payment being processed (online or
  /// declared): not for another.
  final bool inPayment;

  /// #3556 (0805) — the online payment whose open claim names it, the one I
  /// may withdraw; null for a declared payment (it waits for the business).
  final String? claimPaymentId;

  /// #4147 — absent on older hosts; only true offers continuation.
  final bool? claimCanContinue;
  final String? claimPaymentState;

  /// [claimPaymentState] decoded; null when the host names none.
  PaymentClaimState? get claimState => claimPaymentState == null
      ? null
      : PaymentClaimState.fromWire(claimPaymentState);

  /// #4140 — the declared payment, waiting for the business, whose claim
  /// names this invoice: the one I may take back. Null for an online one.
  final String? claimEventId;

  /// #3556 (0805) — when that payment was handed to its provider: in
  /// payment since then.
  final DateTime? claimHandedAt;

  /// #3556 (0805) — it was handed to its provider so recently that a
  /// payment just made there may still be confirmed (the provider's read
  /// age): withdrawing it says so.
  final bool claimSettling;

  /// #3556 (0797) — its money arrived and waits to be matched by the
  /// business: not to pay again.
  final bool paymentReceived;

  /// #3556 (0797) — a payment may name it now (it takes a match, is in the
  /// business's currency, in no payment and has none waiting). False from a
  /// host that does not say: then it is not offered for a selection.
  final bool payable;

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
      period: r.stringOrNull('period'),
      inPayment: r.boolOr('in_payment', fallback: false),
      claimPaymentId: r.stringOrNull('claim_payment_id'),
      claimCanContinue: j['claim_can_continue'] as bool?,
      claimPaymentState: r.stringOrNull('claim_payment_state'),
      claimEventId: r.stringOrNull('claim_event_id'),
      claimHandedAt: r.dateTimeOrNull('claim_handed_at'),
      claimSettling: r.boolOr('claim_settling', fallback: false),
      paymentReceived: r.boolOr('payment_received', fallback: false),
      payable: r.boolOr('payable', fallback: false),
      financialSubjectId: r.stringOrNull('financial_subject_id'),
      billingOnly: r.stringOrNull('access') == 'billing_grant',
    );
  }
}

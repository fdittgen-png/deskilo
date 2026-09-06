// SPDX-License-Identifier: 0BSD
//
// #934 — the workspace's own status for a range of months, as
// `workspace_status` (0167) returns it: what was invoiced, collected,
// reimbursed and shared out, and the same per member. Computed in the
// database so the screen and the printed report read one set of numbers.
import 'expense_repartition.dart';

class WorkspaceStatus {
  const WorkspaceStatus({
    required this.from,
    required this.to,
    required this.currency,
    this.invoicedCents = 0,
    this.creditNotesCents = 0,
    this.byKind = const {},
    this.repartitionChargesCents = 0,
    this.paymentsMatchedCents = 0,
    this.paymentsReceivedCents = 0,
    this.reimbursedCents = 0,
    this.repartitionedCents = 0,
    this.awaitingCents = 0,
    this.creditsGrantedCents = 0,
    this.members = const [],
  });

  final String from;
  final String to;
  final String currency;

  /// Invoices issued with a positive total (non-void, settlements
  /// transparent).
  final int invoicedCents;

  /// The negative ones, as a positive amount.
  final int creditNotesCents;
  final Map<String, int> byKind;

  /// Shares of repartitioned costs charged back to members.
  final int repartitionChargesCents;
  final int paymentsMatchedCents;
  final int paymentsReceivedCents;

  /// Reimbursed to members (ledger credit/expense).
  final int reimbursedCents;

  /// Shared out through confirmed repartitions.
  final int repartitionedCents;

  /// Occurrences still awaiting a member or a validation.
  final int awaitingCents;

  /// Credits granted as adjustments (credit notes booked to the ledger).
  final int creditsGrantedCents;
  final List<StatusMemberRow> members;

  /// What the period leaves: invoiced net of credit notes, less what the
  /// workspace gave back (reimbursements, credits). Repartition shares
  /// are money recovered, so they are not an expense here.
  int get netCents =>
      invoicedCents - creditNotesCents - reimbursedCents - creditsGrantedCents;

  factory WorkspaceStatus.fromJson(Map<String, dynamic> j) {
    final revenue = (j['revenue'] as Map?)?.cast<String, dynamic>() ?? const {};
    final payments = (j['payments'] as Map?)?.cast<String, dynamic>() ?? const {};
    final expenses = (j['expenses'] as Map?)?.cast<String, dynamic>() ?? const {};
    int cents(Map<String, dynamic> m, String k) => (m[k] as num?)?.toInt() ?? 0;
    return WorkspaceStatus(
      from: j['from'] as String? ?? '',
      to: j['to'] as String? ?? '',
      currency: j['currency'] as String? ?? 'EUR',
      invoicedCents: cents(revenue, 'invoiced_cents'),
      creditNotesCents: cents(revenue, 'credit_notes_cents'),
      byKind: {
        for (final e in ((revenue['by_kind'] as Map?) ?? const {}).entries)
          e.key as String: (e.value as num).toInt(),
      },
      repartitionChargesCents: cents(revenue, 'repartition_charges_cents'),
      paymentsMatchedCents: cents(payments, 'matched_cents'),
      paymentsReceivedCents: cents(payments, 'received_cents'),
      reimbursedCents: cents(expenses, 'reimbursed_cents'),
      repartitionedCents: cents(expenses, 'repartitioned_cents'),
      awaitingCents: cents(expenses, 'awaiting_cents'),
      creditsGrantedCents: cents(expenses, 'credits_granted_cents'),
      members: [
        for (final m in (j['members'] as List?) ?? const [])
          StatusMemberRow.fromJson(Map<String, dynamic>.from(m as Map)),
      ],
    );
  }
}

class StatusMemberRow {
  const StatusMemberRow({
    required this.memberId,
    required this.name,
    this.memberNumber = '',
    this.subscriptionPct = 100,
    this.invoicedCents = 0,
    this.paidCents = 0,
    this.reimbursedCents = 0,
    this.creditsCents = 0,
    this.chargedCents = 0,
  });

  final String memberId;
  final String name;
  final String memberNumber;
  final int subscriptionPct;
  final int invoicedCents;
  final int paidCents;
  final int reimbursedCents;
  final int creditsCents;
  final int chargedCents;

  factory StatusMemberRow.fromJson(Map<String, dynamic> j) => StatusMemberRow(
        memberId: j['member_id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        memberNumber: j['member_number'] as String? ?? '',
        subscriptionPct: (j['subscription_pct'] as num?)?.toInt() ?? 100,
        invoicedCents: (j['invoiced_cents'] as num?)?.toInt() ?? 0,
        paidCents: (j['paid_cents'] as num?)?.toInt() ?? 0,
        reimbursedCents: (j['reimbursed_cents'] as num?)?.toInt() ?? 0,
        creditsCents: (j['credits_cents'] as num?)?.toInt() ?? 0,
        chargedCents: (j['charged_cents'] as num?)?.toInt() ?? 0,
      );
}

/// #934 — the repartition rule the wizard proposes month after month:
/// the method, a weight per member for the custom method, and the
/// members left out. Stored in `billing_rules->'repartition'`.
class RepartitionRule {
  const RepartitionRule({
    this.method = RepartitionMethod.subscription,
    this.weights = const {},
    this.excluded = const {},
  });

  final RepartitionMethod method;
  final Map<String, num> weights;
  final Set<String> excluded;

  static const String keyMethod = 'method';
  static const String keyWeights = 'weights';
  static const String keyExcluded = 'excluded';

  factory RepartitionRule.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const RepartitionRule();
    return RepartitionRule(
      method: RepartitionMethod.values
              .where((m) => m.name == j[keyMethod])
              .firstOrNull ??
          RepartitionMethod.subscription,
      weights: {
        for (final e in ((j[keyWeights] as Map?) ?? const {}).entries)
          e.key as String: (e.value as num),
      },
      excluded: {
        for (final id in (j[keyExcluded] as List?) ?? const []) id as String,
      },
    );
  }

  Map<String, Object?> toJson() => {
        keyMethod: method.name,
        keyWeights: weights,
        keyExcluded: excluded.toList(),
      };

  RepartitionRule copyWith({
    RepartitionMethod? method,
    Map<String, num>? weights,
    Set<String>? excluded,
  }) =>
      RepartitionRule(
        method: method ?? this.method,
        weights: weights ?? this.weights,
        excluded: excluded ?? this.excluded,
      );
}

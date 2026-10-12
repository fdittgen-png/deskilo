// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #934 — the workspace's own status for a range of months, as
// `workspace_status` (0167) returns it: what was invoiced, collected,
// reimbursed and shared out, and the same per member. Computed in the
// database so the screen and the printed report read one set of numbers.
import '../../../core/data/json_reader.dart';
import 'accounting_amount.dart';
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
    final r = JsonReader(j, context: 'workspace_status');
    JsonReader section(String key) =>
        r.objectOrNull(key) ??
        (throw FormatException('Missing status section: $key'));
    final currency = r.stringOrNull('currency');
    if (currency == null || !supportedCurrencies.contains(currency)) {
      throw const FormatException('Missing or unsupported status currency');
    }
    final revenue = section('revenue');
    final payments = section('payments');
    final expenses = section('expenses');
    final byKind = revenue.objectOrNull('by_kind');
    if (byKind == null || r.json['members'] is! List) {
      throw const FormatException('Missing status breakdown');
    }
    int cents(JsonReader m, String k) => _minor(m.json[k]);
    return WorkspaceStatus(
      from: r.stringOr('from'),
      to: r.stringOr('to'),
      currency: currency,
      invoicedCents: cents(revenue, 'invoiced_cents'),
      creditNotesCents: cents(revenue, 'credit_notes_cents'),
      byKind: {for (final e in byKind.json.entries) e.key: _minor(e.value)},
      repartitionChargesCents: cents(revenue, 'repartition_charges_cents'),
      paymentsMatchedCents: cents(payments, 'matched_cents'),
      paymentsReceivedCents: cents(payments, 'received_cents'),
      reimbursedCents: cents(expenses, 'reimbursed_cents'),
      repartitionedCents: cents(expenses, 'repartitioned_cents'),
      awaitingCents: cents(expenses, 'awaiting_cents'),
      creditsGrantedCents: cents(expenses, 'credits_granted_cents'),
      members: r.objects('members', (row) => StatusMemberRow.fromJson(row.json)),
    );
  }
}

/// RPC amounts are exact integer minor units, never rounded or defaulted.
int _minor(Object? value) {
  if (value is! num || !value.isFinite ||
      value != value.truncateToDouble() || value.abs() > maxSafeMinor) {
    throw const FormatException('Invalid or missing status amount');
  }
  return value.toInt();
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

  factory StatusMemberRow.fromJson(Map<String, dynamic> j) {
    final r = JsonReader(j, context: 'workspace_status.members');
    return StatusMemberRow(
      memberId: r.stringOr('member_id'),
      name: r.stringOr('name'),
      memberNumber: r.stringOr('member_number'),
      subscriptionPct: r.intOrNull('subscription_pct') ?? 100,
      invoicedCents: _minor(r.json['invoiced_cents']),
      paidCents: _minor(r.json['paid_cents']),
      reimbursedCents: _minor(r.json['reimbursed_cents']),
      creditsCents: _minor(r.json['credits_cents']),
      chargedCents: _minor(r.json['charged_cents']),
    );
  }
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
    final r = JsonReader(j, context: 'repartition_rule');
    final weights = r.objectOrNull(keyWeights);
    return RepartitionRule(
      method: RepartitionMethod.values
              .where((m) => m.name == r.stringOrNull(keyMethod))
              .firstOrNull ??
          RepartitionMethod.subscription,
      weights: {
        if (weights != null)
          for (final key in weights.json.keys) key: weights.numeric(key),
      },
      excluded: r.strings(keyExcluded).toSet(),
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

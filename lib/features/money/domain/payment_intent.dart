import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
// SPDX-License-Identifier: AGPL-3.0-or-later

/// One online-payment attempt (migration 0045): the provider order the
/// app started and what became of it. Admin-readable for diagnostics and
/// for the payments tab of the data export (#395) — the ONLINE third of
/// confirmed / unconfirmed / online.
class PaymentIntent implements SystemStamped {
  const PaymentIntent({
    required this.id,
    required this.memberId,
    required this.provider,
    required this.orderId,
    required this.period,
    required this.amountCents,
    required this.status,
    required this.createdAt,
    this.captureId = '',
    this.reference = '',
    this.reversedAt,
    this.reversalReason = '',
    this.reversalReviewedAt,
    this.system = SystemColumns.none,
  });

  /// #992 — the server's stamp on this row.
  @override
  final SystemColumns system;

  final String id;
  final String memberId;

  /// 'paypal' | 'stripe' | 'mollie' | 'wero'.
  final String provider;
  final String orderId;

  /// Set on capture; the idempotency handle of settlement.
  final String captureId;
  /// #928 — PAY-2026-0117: what the payer saw at checkout and what the
  /// bank statement carries.
  final String reference;
  final String period;
  final int amountCents;

  /// 'created' | 'captured' | 'failed' | 'reversed' (#3905).
  final String status;
  final DateTime createdAt;

  /// #3905 — when the provider reported the payment reversed, and why (the
  /// kind of reversal with its amount); null and empty otherwise.
  final DateTime? reversedAt;
  final String reversalReason;

  /// #3925 — when someone who sees the finances looked at the reversal;
  /// null while it waits for them.
  final DateTime? reversalReviewedAt;

  /// #3925 — a reversal nobody has looked at yet: the books may still need
  /// correcting.
  bool get awaitsReview => status == 'reversed' && reversalReviewedAt == null;

  /// #3925 — the amount the provider reversed, in minor units of
  /// [currency], read from [reversalReason]: its last two words are the
  /// amount and its currency, as the webhooks write them (0757). Null when
  /// the reason names no amount, or one in another currency.
  int? reversedMinor(String currency) {
    final m = RegExp(r'(\d+(?:\.\d+)?) ([A-Z]{3})$')
        .firstMatch(reversalReason.trim());
    if (m == null || m.group(2) != currency.trim().toUpperCase()) return null;
    try {
      final exponent = exponentOf(m.group(2)!);
      final amount = ExactDecimal.parse(m.group(1)!);
      if (amount.scale > exponent) return null;
      return (amount.units * BigInt.from(10).pow(exponent - amount.scale))
          .toInt();
    } on AccountingException {
      return null;
    }
  }

  /// The same payment, its reversal looked at [at].
  PaymentIntent reviewedAt(DateTime at) => PaymentIntent(
        id: id,
        memberId: memberId,
        provider: provider,
        orderId: orderId,
        period: period,
        amountCents: amountCents,
        status: status,
        createdAt: createdAt,
        captureId: captureId,
        reference: reference,
        reversedAt: reversedAt,
        reversalReason: reversalReason,
        reversalReviewedAt: at,
        system: system,
      );

  factory PaymentIntent.fromRow(Map<String, dynamic> row) => PaymentIntent(
        system: SystemColumns.fromRow(row),
        id: row['id'] as String,
        memberId: row['member_id'] as String,
        provider: row['provider'] as String,
        orderId: row['order_id'] as String,
        captureId: row['capture_id'] as String? ?? '',
        reference: row['reference'] as String? ?? '',
        period: row['period'] as String,
        amountCents: row['amount_cents'] as int,
        status: row['status'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        reversedAt: row['reversed_at'] == null ? null : DateTime.parse(row['reversed_at'] as String),
        reversalReason: row['reversal_reason'] as String? ?? '',
        reversalReviewedAt: row['reversal_reviewed_at'] == null
            ? null
            : DateTime.parse(row['reversal_reviewed_at'] as String),
      );
}

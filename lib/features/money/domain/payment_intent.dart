// SPDX-License-Identifier: 0BSD

/// One online-payment attempt (migration 0045): the provider order the
/// app started and what became of it. Admin-readable for diagnostics and
/// for the payments tab of the data export (#395) — the ONLINE third of
/// confirmed / unconfirmed / online.
class PaymentIntent {
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
  });

  final String id;
  final String memberId;

  /// 'paypal' | 'stripe' | 'mollie' | 'wero'.
  final String provider;
  final String orderId;

  /// Set on capture; the idempotency handle of settlement.
  final String captureId;
  final String period;
  final int amountCents;

  /// 'created' | 'captured' | 'failed'.
  final String status;
  final DateTime createdAt;

  factory PaymentIntent.fromRow(Map<String, dynamic> row) => PaymentIntent(
        id: row['id'] as String,
        memberId: row['member_id'] as String,
        provider: row['provider'] as String,
        orderId: row['order_id'] as String,
        captureId: row['capture_id'] as String? ?? '',
        period: row['period'] as String,
        amountCents: row['amount_cents'] as int,
        status: row['status'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}

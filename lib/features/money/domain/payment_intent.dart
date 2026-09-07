import '../../../core/data/system_columns.dart';
// SPDX-License-Identifier: 0BSD

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

  /// 'created' | 'captured' | 'failed'.
  final String status;
  final DateTime createdAt;

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
      );
}

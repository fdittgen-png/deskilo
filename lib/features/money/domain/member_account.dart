// SPDX-License-Identifier: 0BSD

/// One open invoice as the account view lists it (#512): what the
/// document asks, what validated instalments covered, what remains.
typedef OpenInvoicePosition = ({
  String invoiceId,
  String number,
  String period,
  int totalCents,
  int paidCents,
  int remainingCents,
});

/// The member's REAL cross-month position (#512), mirrored from the
/// `member_account` RPC: months are not islands — credit on account,
/// open remainders from any month, refunds the workspace owes, and the
/// resulting net. Positive [netPositionCents] = the workspace owes the
/// member; negative = the member still owes.
class MemberAccount {
  const MemberAccount({
    required this.creditCents,
    required this.openInvoices,
    required this.openTotalCents,
    required this.refundsDueCents,
    required this.netPositionCents,
  });

  factory MemberAccount.fromJson(Map<String, dynamic> json) => MemberAccount(
        creditCents: json['credit_cents'] as int? ?? 0,
        openInvoices: [
          for (final row in (json['open_invoices'] as List? ?? const []))
            (
              invoiceId: row['invoice_id'] as String,
              number: row['number'] as String,
              period: row['period'] as String? ?? '',
              totalCents: row['total_cents'] as int,
              paidCents: row['paid_cents'] as int? ?? 0,
              remainingCents: row['remaining_cents'] as int,
            ),
        ],
        openTotalCents: json['open_total_cents'] as int? ?? 0,
        refundsDueCents: json['refunds_due_cents'] as int? ?? 0,
        netPositionCents: json['net_position_cents'] as int? ?? 0,
      );

  /// Unconsumed, un-baked ledger credits — money the member has "on
  /// account", spendable on any outstanding invoice (imputation).
  final int creditCents;

  /// Open positive invoices at their remaining value, oldest first.
  final List<OpenInvoicePosition> openInvoices;

  /// Sum of [openInvoices] remainders.
  final int openTotalCents;

  /// Open credit notes the workspace still has to refund.
  final int refundsDueCents;

  /// credit + refunds due − open remainders.
  final int netPositionCents;

  static const empty = MemberAccount(
    creditCents: 0,
    openInvoices: [],
    openTotalCents: 0,
    refundsDueCents: 0,
    netPositionCents: 0,
  );

  /// Whether there is anything worth a card: settled, creditless
  /// accounts with no open documents stay invisible.
  bool get isNotable =>
      creditCents != 0 || openInvoices.isNotEmpty || refundsDueCents != 0;
}

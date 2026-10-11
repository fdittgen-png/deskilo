// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/json_reader.dart';

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

  /// #2387 — read through [JsonReader]; the context names the RPC.
  factory MemberAccount.fromJson(Map<String, dynamic> json) {
    final r = JsonReader(json, context: 'member_account');
    return MemberAccount(
      creditCents: r.intOrNull('credit_cents') ?? 0,
      openInvoices: r.objects(
        'open_invoices',
        (row) => (
          invoiceId: row.string('invoice_id'),
          number: row.string('number'),
          period: row.stringOr('period'),
          totalCents: row.integer('total_cents'),
          paidCents: row.intOrNull('paid_cents') ?? 0,
          remainingCents: row.integer('remaining_cents'),
        ),
      ),
      openTotalCents: r.intOrNull('open_total_cents') ?? 0,
      refundsDueCents: r.intOrNull('refunds_due_cents') ?? 0,
      netPositionCents: r.intOrNull('net_position_cents') ?? 0,
    );
  }

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

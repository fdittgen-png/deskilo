// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ledger_entry.freezed.dart';

enum LedgerKind { charge, credit }

enum LedgerCategory {
  subscription,
  overage,
  expense,
  payment,
  adjustment,
  service,
  package,

  /// A credit note paid back by bank transfer (0436, #2570): money returned,
  /// never a charge for the next invoice.
  refund,

  /// Cash paid to a member against an approved claim (0467, #2574): a
  /// charge that is never an invoice line, or its reversal as a credit.
  reimbursement,
}

/// One line on a member's ledger (spec §7.3).
@freezed
sealed class LedgerEntry with _$LedgerEntry implements SystemStamped {
  const LedgerEntry._();

  const factory LedgerEntry({
    required String id,
    required String memberId,
    required LedgerKind kind,
    required LedgerCategory category,
    required int amountCents,
    required String description,
    required String period,

    /// When the entry was BOOKED — the audit stamp, never editable.
    required DateTime createdAt,

    /// When the money actually moved (0070). A transfer made on the 3rd
    /// and recorded on the 26th is dated the 3rd; null on entries booked
    /// before 0070 and on those where booking IS the event.
    DateTime? occurredOn,

    /// #4165 (0901) — how the entry is spent: `legacy` by the month rules,
    /// `explicit` only by the allocations that name it (a payment of invoices
    /// without a month, posted in the month it arrived).
    @Default('legacy') String allocationMode,
    /// #992 — the server's stamp on this row.
    @Default(SystemColumns.none) SystemColumns system,
  }) = _LedgerEntry;

  /// The date to SHOW and to sort by: what happened, falling back to when
  /// it was booked.
  DateTime get on => occurredOn ?? createdAt;
}

/// #3913 — the ledger rows a read left out (a kind or a category this build
/// does not know): per member for their account, `ws:<id>` for the whole
/// workspace's ledger.
String ledgerArea(String scope) => 'ledger:$scope';

/// #3913 — a figure over the ledger refused because some of its rows are of
/// a kind or a category this version cannot read: the figure is not known,
/// never a smaller one.
class LedgerRowsUnreadable implements Exception {
  const LedgerRowsUnreadable();

  @override
  String toString() => 'LedgerRowsUnreadable';
}

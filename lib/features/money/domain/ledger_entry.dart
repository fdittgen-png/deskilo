// SPDX-License-Identifier: 0BSD
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
}

/// One line on a member's ledger (spec §7.3).
@freezed
sealed class LedgerEntry with _$LedgerEntry {
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
  }) = _LedgerEntry;

  /// The date to SHOW and to sort by: what happened, falling back to when
  /// it was booked.
  DateTime get on => occurredOn ?? createdAt;
}

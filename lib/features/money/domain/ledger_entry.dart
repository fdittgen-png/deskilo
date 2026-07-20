// SPDX-License-Identifier: MIT
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
  const factory LedgerEntry({
    required String id,
    required String memberId,
    required LedgerKind kind,
    required LedgerCategory category,
    required int amountCents,
    required String description,
    required String period,
    required DateTime createdAt,
  }) = _LedgerEntry;
}

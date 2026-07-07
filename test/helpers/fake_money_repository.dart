// SPDX-License-Identifier: MIT
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/money_repository.dart';
import 'package:deskilo/features/money/domain/statement.dart';

/// In-memory [MoneyRepository]; recorded payments are captured for
/// assertions (they only become ledger credits after confirmation).
class FakeMoneyRepository implements MoneyRepository {
  Statement statement = const Statement(
    period: '2026-07',
    planName: 'Half',
    baseFeeCents: 15000,
    includedHalfDays: 22,
    usedHalfDays: 24,
    extraHalfDays: 2,
    overageCents: 1600,
    creditsCents: 15000,
    balanceCents: -1600,
  );

  final ledger = <LedgerEntry>[];
  final recordedPayments = <({int amountCents, String note})>[];

  @override
  Future<Statement> fetchStatement(String memberId, String period) async =>
      statement;

  @override
  Future<List<LedgerEntry>> fetchLedger(String memberId) async =>
      List.of(ledger);

  @override
  Future<String> recordPayment({
    required String workspaceId,
    required String memberId,
    required int amountCents,
    String note = '',
  }) async {
    recordedPayments.add((amountCents: amountCents, note: note));
    return 'evt-payment-${recordedPayments.length}';
  }
}

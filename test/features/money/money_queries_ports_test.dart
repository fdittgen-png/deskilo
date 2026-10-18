// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2591 C1 — the invoice and account reads are ports of their own: a
// consumer of one is built with a fake of that port alone, and the
// composed repository hands every call to the port it was given.
import 'package:deskilo/features/money/data/supabase_money_repository.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/command_receipt.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_queries.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/member_account.dart';
import 'package:deskilo/features/money/domain/member_account_queries.dart';
import 'package:deskilo/features/money/domain/reminder_evidence.dart';
import 'package:deskilo/features/money/domain/statement.dart';
import 'package:deskilo/features/money/domain/usage_record.dart';
import 'package:deskilo/features/money/domain/vat_tax_point.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/reminder_evidence_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _InvoiceReads implements InvoiceQueries {
  final calls = <String>[];

  @override
  Future<CommandReceipt> invoiceCommandOutcome({
    required String workspaceId,
    required String requestId,
  }) async => const CommandReceipt(CommandReceiptState.notObserved);

  @override
  Future<List<ReminderEvidence>> fetchReminderEvidence(String invoiceId) async {
    calls.add('evidence:$invoiceId');
    return const [];
  }

  @override
  Future<List<Invoice>> fetchInvoices(String workspaceId) async {
    calls.add('invoices:$workspaceId');
    return const [];
  }

  @override
  Future<Set<String>> fetchConsumedPaymentIds(String workspaceId) async =>
      const {};

  @override
  Future<({List<InvoiceLine> lines, int totalCents})> previewInvoice({
    required String workspaceId,
    required String memberId,
    required String period,
  }) async {
    calls.add('preview:$memberId:$period');
    return (lines: const <InvoiceLine>[], totalCents: 0);
  }

  @override
  Future<List<String>> invoiceIssueReadiness({
    required String workspaceId,
    required String memberId,
    required String period,
    InvoiceKind kind = InvoiceKind.full,
    String? replacesId,
    String correctionReason = '',
  }) async => const [];

  @override
  Future<Map<String, InvoiceMatch>> fetchInvoiceMatches(
    String workspaceId,
  ) async => const {};

  @override
  Future<Map<String, List<TaxPointPayment>>> fetchInvoiceInstalments(
    String workspaceId,
  ) async => const {};

  @override
  Future<Map<String, ({int count, DateTime last})>> fetchInvoiceReminders(
    String workspaceId,
  ) async => const {};
}

class _AccountReads implements MemberAccountQueries {
  final calls = <String>[];

  @override
  Future<MemberAccount> fetchMemberAccount(String memberId) async {
    calls.add('account:$memberId');
    return MemberAccount.empty;
  }

  @override
  Future<Statement> fetchStatement(String memberId, String period) =>
      throw UnimplementedError();

  @override
  Future<List<LedgerEntry>> fetchLedger(String memberId) async => const [];

  @override
  Future<List<LedgerEntry>> fetchWorkspaceLedger(String workspaceId) async =>
      const [];

  @override
  Future<UsageRead> readUsageRecords({
    required String workspaceId,
    required String period,
    String? memberId,
  }) async => const UsageRead(records: []);
}

void main() {
  test('a reminder-evidence consumer needs the invoice reads alone', () async {
    final reads = _InvoiceReads();
    final container = ProviderContainer(
      overrides: [invoiceQueriesProvider.overrideWithValue(reads)],
    );
    addTearDown(container.dispose);

    await container.read(reminderEvidenceProvider('inv-1').future);

    expect(reads.calls, ['evidence:inv-1']);
  });

  test('the composed repository hands each read to its own port', () async {
    final invoices = _InvoiceReads();
    final accounts = _AccountReads();
    final repo = SupabaseMoneyRepository(
      SupabaseClient('http://localhost', 'anon'),
      invoices: invoices,
      accounts: accounts,
    );

    await repo.fetchInvoices('w1');
    await repo.previewInvoice(
      workspaceId: 'w1',
      memberId: 'm1',
      period: '2026-10',
    );
    await repo.fetchMemberAccount('m1');

    expect(invoices.calls, ['invoices:w1', 'preview:m1:2026-10']);
    expect(accounts.calls, ['account:m1']);
  });
}

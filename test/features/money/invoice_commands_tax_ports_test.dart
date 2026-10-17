// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2591 C3 — the invoice commands and the VAT reporting are ports of their
// own: a decision class is built with a fake of the ports it needs alone,
// and the composed repository hands every call to the port it was given.
import 'package:deskilo/features/money/application/declare_vat.dart';
import 'package:deskilo/features/money/application/settle_invoices.dart';
import 'package:deskilo/features/money/data/supabase_money_repository.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/command_receipt.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_action_commands.dart';
import 'package:deskilo/features/money/domain/invoice_commands.dart';
import 'package:deskilo/features/money/domain/invoice_queries.dart';
import 'package:deskilo/features/money/domain/reminder_evidence.dart';
import 'package:deskilo/features/money/domain/tax_reporting_repository.dart';
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/domain/vat_tax_point.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Commands implements InvoiceCommands {
  final calls = <String>[];

  @override
  Future<String> createInvoice({
    required String workspaceId,
    required String memberId,
    required String period,
    String? replacesId,
    bool detailed = false,
    InvoiceKind kind = InvoiceKind.full,
    String buyerReference = '',
    String purchaseOrder = '',
    String correctionReason = '',
  }) async {
    calls.add('create:$memberId:$period');
    return 'inv-1';
  }

  @override
  Future<String> issueInvoiceWithReceipt(InvoiceIssueCommand command) async {
    calls.add('issue:${command.memberId}:${command.period}:${command.requestId}');
    return 'inv-1';
  }

  @override
  Future<void> voidInvoice(String invoiceId) async =>
      calls.add('void:$invoiceId');

  @override
  Future<void> remindInvoice(String invoiceId) async =>
      calls.add('remind:$invoiceId');

  @override
  Future<void> settleCreditInvoice(
    String invoiceId, {
    String note = '',
  }) async => calls.add('credit:$invoiceId');

  @override
  Future<String> settleInvoices({
    required String workspaceId,
    required String memberId,
    required List<String> invoiceIds,
    String note = '',
  }) async {
    calls.add('settle:${invoiceIds.join(',')}');
    return 'settlement-1';
  }

  @override
  Future<void> matchInvoice({
    required String invoiceId,
    required String paymentLedgerId,
    required String resolution,
    String note = '',
  }) async => calls.add('match:$invoiceId:$resolution');
}

class _Tax implements TaxReportingRepository {
  final calls = <String>[];

  @override
  Future<List<VatDeclaration>> fetchVatDeclarations(String workspaceId) async {
    calls.add('declarations:$workspaceId');
    return const [];
  }

  @override
  Future<String> saveVatDeclaration({
    required String workspaceId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    calls.add('save:$workspaceId');
    return 'decl-1';
  }

  @override
  Future<void> markVatDeclarationSubmitted({
    required String declarationId,
    required String channel,
    required String receipt,
  }) async => calls.add('submitted:$declarationId:$channel');

  @override
  Future<List<VatRate>> fetchVatRates(String workspaceId) async {
    calls.add('rates:$workspaceId');
    return const [];
  }

  @override
  Future<void> setVatRates(String workspaceId, List<VatRate> rates) async =>
      calls.add('setRates:$workspaceId');
}

/// The reads the decision classes use, and nothing else answers.
class _Reads implements InvoiceQueries {
  @override
  Future<CommandReceipt> invoiceCommandOutcome({
    required String workspaceId,
    required String requestId,
  }) async => const CommandReceipt(CommandReceiptState.notObserved);

  @override
  Future<List<Invoice>> fetchInvoices(String workspaceId) async => const [];

  @override
  Future<Map<String, List<TaxPointPayment>>> fetchInvoiceInstalments(
    String workspaceId,
  ) async => const {};

  @override
  Future<Set<String>> fetchConsumedPaymentIds(String workspaceId) async =>
      const {};

  @override
  Future<({List<InvoiceLine> lines, int totalCents})> previewInvoice({
    required String workspaceId,
    required String memberId,
    required String period,
  }) async => (lines: const <InvoiceLine>[], totalCents: 0);

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
  Future<List<ReminderEvidence>> fetchReminderEvidence(
    String invoiceId,
  ) async => const [];

  @override
  Future<Map<String, ({int count, DateTime last})>> fetchInvoiceReminders(
    String workspaceId,
  ) async => const {};

  @override
  Future<Map<String, InvoiceMatch>> fetchInvoiceMatches(
    String workspaceId,
  ) async => const {};
}

/// The receipted acts, recorded.
class _Actions implements InvoiceActionCommands {
  final calls = <String>[];

  @override
  Future<String> settleInvoicesOnce({
    required String workspaceId,
    required String memberId,
    required List<String> invoiceIds,
    required String requestId,
    String note = '',
  }) async {
    calls.add('settle:${invoiceIds.join(',')}:$requestId');
    return 'settlement-1';
  }

  @override
  Future<String> createInvoiceOnce(InvoiceIssueCommand command) async =>
      'inv-1';

  @override
  Future<void> voidInvoice(
    String invoiceId, {
    required String requestId,
    String reason = '',
  }) async {}

  @override
  Future<void> settleCreditInvoice(
    String invoiceId, {
    required String requestId,
    String note = '',
  }) async {}
}

void main() {
  test('settling needs the action commands and reads alone', () async {
    final actions = _Actions();
    final outcome = await Settlements(actions, _Reads()).settle(
      const SettleAttempt(
        workspaceId: 'w1',
        memberId: 'm1',
        invoiceIds: ['a', 'b'],
        requestId: 'req-1',
      ),
    );

    expect(actions.calls, ['settle:a,b:req-1']);
    // The fresh list does not carry the new document: the id is quoted.
    expect((outcome as Settled).number, 'settlement-1');
  });

  test(
    'declaring VAT needs the tax port and the invoice reads alone',
    () async {
      final tax = _Tax();
      final declarations = VatDeclarations(tax, _Reads());

      await declarations.declare(
        workspaceId: 'w1',
        periodStart: DateTime.utc(2026, 7),
        periodEnd: DateTime.utc(2026, 9, 30),
      );
      await declarations.fileByHand('decl-1', receipt: 'R-1');

      expect(tax.calls, ['save:w1', 'submitted:decl-1:manual']);
    },
  );

  test('the composed repository hands each call to its own port', () async {
    final commands = _Commands();
    final tax = _Tax();
    final repo = SupabaseMoneyRepository(
      SupabaseClient('http://localhost', 'anon'),
      commands: commands,
      tax: tax,
    );

    await repo.createInvoice(
      workspaceId: 'w1',
      memberId: 'm1',
      period: '2026-10',
    );
    await repo.voidInvoice('i1');
    await repo.remindInvoice('i1');
    await repo.settleCreditInvoice('i2');
    await repo.matchInvoice(
      invoiceId: 'i1',
      paymentLedgerId: 'p1',
      resolution: 'exact',
    );
    await repo.fetchVatDeclarations('w1');
    await repo.fetchVatRates('w1');
    await repo.setVatRates('w1', const []);

    expect(commands.calls, [
      'create:m1:2026-10',
      'void:i1',
      'remind:i1',
      'credit:i2',
      'match:i1:exact',
    ]);
    expect(tax.calls, ['declarations:w1', 'rates:w1', 'setRates:w1']);
  });
}

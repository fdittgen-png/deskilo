// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/features/money/domain/command_receipt.dart';
import 'package:deskilo/features/money/domain/invoice_action_commands.dart';

import '../money_repository.dart';

/// #2585 C2 — void / refund under a request id for the demo and the tests:
/// the act runs on the fake repository once, and its receipt is read back by
/// the same id through [FakeMoneyRepository.invoiceCommandOutcome].
class FakeInvoiceActionCommands implements InvoiceActionCommands {
  FakeInvoiceActionCommands(this._repo);

  final FakeMoneyRepository _repo;

  Future<void> _once(
    String invoiceId,
    String requestId,
    Future<void> Function() act,
  ) async {
    final receipts = _repo.invoiceReceipts;
    final invoice = _repo.invoices.firstWhere(
      (i) => i.id == invoiceId,
      orElse: () => throw StateError('unknown invoice'),
    );
    final key = '${invoice.workspaceId}|$requestId';
    if (receipts.containsKey(key)) return;
    await act();
    receipts[key] = invoiceId;
  }

  @override
  Future<String> createInvoiceOnce(InvoiceIssueCommand c) async {
    final receipts = _repo.invoiceReceipts;
    final key = '${c.workspaceId}|${c.requestId}';
    final known = receipts[key];
    if (known != null) return known;
    final id = await _repo.createInvoice(
      workspaceId: c.workspaceId,
      memberId: c.memberId,
      period: c.period,
      kind: c.kind,
    );
    return receipts[key] = id;
  }

  @override
  Future<String> replaceInvoiceOnce(InvoiceIssueCommand c) async {
    final receipts = _repo.invoiceReceipts;
    final key = '${c.workspaceId}|${c.requestId}';
    final known = receipts[key];
    if (known != null) return known;
    final id = await _repo.createInvoice(
      workspaceId: c.workspaceId,
      memberId: c.memberId,
      period: c.period,
      replacesId: c.replacesId,
      detailed: c.detailed,
      kind: c.kind,
      buyerReference: c.buyerReference,
      purchaseOrder: c.purchaseOrder,
      correctionReason: c.correctionReason,
    );
    return receipts[key] = id;
  }

  @override
  Future<String> settleInvoicesOnce({
    required String workspaceId,
    required String memberId,
    required List<String> invoiceIds,
    required String requestId,
    String note = '',
  }) async {
    final receipts = _repo.invoiceReceipts;
    final key = '$workspaceId|$requestId';
    final known = receipts[key];
    if (known != null) return known;
    final id = await _repo.settleInvoices(
      workspaceId: workspaceId,
      memberId: memberId,
      invoiceIds: invoiceIds,
      note: note,
    );
    return receipts[key] = id;
  }

  @override
  Future<void> voidInvoice(
    String invoiceId, {
    required String requestId,
    String reason = '',
  }) => _once(invoiceId, requestId, () => _repo.voidInvoice(invoiceId));

  @override
  Future<void> settleCreditInvoice(
    String invoiceId, {
    required String requestId,
    String note = '',
  }) => _once(
    invoiceId,
    requestId,
    () => _repo.settleCreditInvoice(invoiceId, note: note),
  );
}

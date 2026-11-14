// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3960 — invoices by e-mail in the Demo: the session's outbox records the
// send and answers as the server does; nothing leaves the device.
import '../../../../features/money/domain/invoice_mail.dart';
import 'demo_outbox.dart';

class DemoInvoiceMail implements InvoiceMail {
  const DemoInvoiceMail(this._outbox);

  final DemoOutbox _outbox;

  @override
  Future<InvoiceMailView> state(String workspaceId, String invoiceId) =>
      _outbox.state(workspaceId, invoiceId);

  @override
  Future<InvoiceMailSend> send({
    required String workspaceId,
    required String invoiceId,
    required InvoiceMailKind kind,
    required String attemptId,
    required InvoiceMailLetter letter,
  }) => _outbox.sendInvoice(
    workspaceId: workspaceId,
    invoiceId: invoiceId,
    kind: kind,
    attemptId: attemptId,
    letter: letter,
  );

  // Every e-mail of the outbox is accepted: none is left to decide.
  @override
  Future<InvoiceMailSend> resolve(
    String workspaceId,
    String attemptId, {
    required bool delivered,
  }) => _outbox.resolveInvoice(attemptId);
}

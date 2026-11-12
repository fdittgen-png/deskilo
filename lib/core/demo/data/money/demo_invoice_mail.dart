// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — the Demo sends no e-mail: invoices by e-mail are left off in
// every Demo space (demo_flags.dart); if one were switched on, the page
// says the feature is off and a send is refused before anything leaves.
import '../../../../features/money/domain/invoice_mail.dart';

class DemoInvoiceMail implements InvoiceMail {
  const DemoInvoiceMail();

  @override
  Future<InvoiceMailView> state(String workspaceId, String invoiceId) async =>
      const InvoiceMailView(
        available: false,
        reason: InvoiceMailUnavailable.featureOff,
      );

  @override
  Future<InvoiceMailSend> send({
    required String workspaceId,
    required String invoiceId,
    required InvoiceMailKind kind,
    required String attemptId,
    required InvoiceMailLetter letter,
  }) => Future.error(StateError('the Demo sends no e-mail'));

  @override
  Future<InvoiceMailSend> resolve(
    String workspaceId,
    String attemptId, {
    required bool delivered,
  }) => Future.error(StateError('the Demo sends no e-mail'));
}

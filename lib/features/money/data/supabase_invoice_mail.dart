// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — invoices by e-mail against the server: the state and the decision
// are RPCs (0730), the send is the `send-invoice-email` function, which
// holds the key. Its refusals read as a reminder's do (supabase_reminder_
// mail.dart): 409 is the fence, any other 4xx a refusal.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/invoice_mail.dart';
import 'supabase_reminder_mail.dart';

class SupabaseInvoiceMail implements InvoiceMail {
  SupabaseInvoiceMail(this._client);

  final SupabaseClient _client;

  @override
  Future<InvoiceMailView> state(String workspaceId, String invoiceId) async =>
      InvoiceMailView.fromJson(
        await _client.rpc<Object?>(
          'invoice_email_state_v1',
          params: {'p_workspace_id': workspaceId, 'p_invoice_id': invoiceId},
        ),
      );

  @override
  Future<InvoiceMailSend> send({
    required String workspaceId,
    required String invoiceId,
    required InvoiceMailKind kind,
    required String attemptId,
    required InvoiceMailLetter letter,
  }) async {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'send-invoice-email',
        body: {
          'workspace_id': workspaceId,
          'invoice_id': invoiceId,
          'kind': kind.wire,
          'language': letter.language,
          'attempt_id': attemptId,
          'subject': letter.subject,
          'text': letter.text,
          'pdf_base64': letter.pdfBase64,
          'file_name': letter.fileName,
        },
      );
    } on FunctionException catch (e, st) {
      Error.throwWithStackTrace(SupabaseReminderMail.refusalOf(e) ?? e, st);
    }
    return InvoiceMailSend.fromJson(response.data);
  }

  @override
  Future<InvoiceMailSend> resolve(
    String workspaceId,
    String attemptId, {
    required bool delivered,
  }) async => InvoiceMailSend.fromJson(
    await _client.rpc<Object?>(
      'resolve_invoice_email_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_attempt_id': attemptId,
        'p_delivered': delivered,
      },
    ),
  );
}

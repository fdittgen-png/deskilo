// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — reminders by e-mail against the server: the target and the
// decision are RPCs (0726), the send is the `send-reminder-email` function,
// which holds the key.
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/reminder_mail.dart';

class SupabaseReminderMail implements ReminderMail {
  SupabaseReminderMail(this._client);

  final SupabaseClient _client;

  @override
  Future<ReminderMailTarget> target(
    String workspaceId,
    String invoiceId,
  ) async => ReminderMailTarget.fromJson(
    await _client.rpc<Object?>(
      'reminder_email_target_v1',
      params: {'p_workspace_id': workspaceId, 'p_invoice_id': invoiceId},
    ),
  );

  @override
  Future<List<ReminderMailSend>> awaiting(
    String workspaceId,
    String invoiceId,
  ) async {
    final rows = await _client
        .from('reminder_email_sends')
        .select()
        .eq('workspace_id', workspaceId)
        .eq('invoice_id', invoiceId)
        // Unconfirmed, or pending (a crash after the send leaves no
        // answer): the server decides which of them a person may settle.
        .inFilter('state', [
          ReminderMailState.unconfirmed.wire,
          ReminderMailState.pending.wire,
        ])
        .order('created_datetime', ascending: false);
    return [for (final row in rows) ReminderMailSend.fromJson(row)];
  }

  @override
  Future<ReminderMailSend> send({
    required String workspaceId,
    required String invoiceId,
    required int level,
    required String attemptId,
    required ReminderMailLetter letter,
  }) async {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'send-reminder-email',
        body: {
          'workspace_id': workspaceId,
          'invoice_id': invoiceId,
          'level': level,
          'language': letter.language,
          'attempt_id': attemptId,
          'subject': letter.subject,
          'text': letter.text,
          'pdf_base64': letter.pdfBase64,
          'file_name': letter.fileName,
        },
      );
    } on FunctionException catch (e, st) {
      Error.throwWithStackTrace(refusalOf(e) ?? e, st);
    }
    return ReminderMailSend.fromJson(response.data);
  }

  /// The function's refusals (send-reminder-email): 409 is the fence, any
  /// other 4xx a refusal; a 5xx may not have reached the database.
  @visibleForTesting
  static ReminderMailRefusal? refusalOf(FunctionException e) {
    final details = e.details;
    final body = details is Map ? details : const <String, Object?>{};
    if (e.status == 409) {
      return body['code'] == '40001'
          ? const ReminderMailLevelChanged()
          : const ReminderMailAwaitsDecision();
    }
    if (e.status >= 400 && e.status < 500) {
      return ReminderMailRefused('${body['error'] ?? e.reasonPhrase ?? ''}');
    }
    return null;
  }

  @override
  Future<ReminderMailSend> resolve(
    String workspaceId,
    String attemptId, {
    required bool delivered,
  }) async => ReminderMailSend.fromJson(
    await _client.rpc<Object?>(
      'resolve_reminder_email_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_attempt_id': attemptId,
        'p_delivered': delivered,
      },
    ),
  );
}

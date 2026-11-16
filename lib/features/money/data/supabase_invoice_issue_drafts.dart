// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4105 -- the dry run of an issue, with the parties it would store
// (`invoice_issue_draft`, 0792).
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/invoice_issue_draft.dart';

class SupabaseInvoiceIssueDrafts implements InvoiceIssueDrafts {
  const SupabaseInvoiceIssueDrafts(this._client);

  final SupabaseClient _client;

  @override
  Future<IssueDraft> issueDraft({
    required String workspaceId,
    required String memberId,
    required String period,
    InvoiceKind kind = InvoiceKind.full,
    String? replacesId,
    String correctionReason = '',
  }) async {
    final answer = await _client.rpc<dynamic>(
      'invoice_issue_draft',
      params: {
        'p_workspace_id': workspaceId,
        'p_member_id': memberId,
        'p_period': period,
        'p_kind': kind.name,
        'p_replaces': replacesId,
        'p_correction_reason': correctionReason,
      },
    );
    return IssueDraft.fromAnswer(answer as Map<dynamic, dynamic>);
  }
}

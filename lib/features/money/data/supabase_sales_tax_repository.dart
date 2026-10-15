// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/time/date_text.dart';
import '../domain/sales_tax_repository.dart';
import '../domain/sales_tax_return.dart';
import '../domain/tax_exemption_certificate.dart';

/// #2362 -- the `sales_tax_return` function (migration 0439).
class SupabaseSalesTaxRepository implements SalesTaxRepository {
  const SupabaseSalesTaxRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<SalesTaxReturnRow>> fetchReturn(
    String workspaceId, {
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await _client.rpc<Object?>(
      'sales_tax_return',
      params: {
        'p_workspace_id': workspaceId,
        'p_start': isoDay(start),
        'p_end': isoDay(end),
      },
    );
    return [
      for (final row in rows as List<Object?>)
        ?SalesTaxReturnRow.fromJson(row! as Map<Object?, Object?>),
    ];
  }

  @override
  Future<List<TaxExemptionCertificate>> fetchCertificates(
    String memberId,
  ) async {
    final rows = await _client
        .from('tax_exemption_certificates')
        .select('id, kind, state, number, valid_from, valid_to')
        .eq('member_id', memberId)
        .order('valid_from', ascending: false);
    return [for (final row in rows) TaxExemptionCertificate.fromRow(row)];
  }

  @override
  Future<void> saveCertificate(TaxExemptionCertificateDraft draft) async {
    await _client.rpc<Object?>(
      'set_tax_exemption_certificate',
      params: {
        'p_workspace_id': draft.workspaceId,
        'p_member_id': draft.memberId,
        'p_kind': draft.kind,
        'p_state': draft.state,
        'p_number': draft.number,
        'p_valid_from': isoDay(draft.validFrom),
        'p_valid_to': draft.validTo == null ? null : isoDay(draft.validTo!),
        'p_file_path': '',
      },
    );
  }

  @override
  Future<void> endCertificate(String id, DateTime on) async {
    await _client.rpc<Object?>(
      'end_tax_exemption_certificate',
      params: {'p_id': id, 'p_on': isoDay(on)},
    );
  }
}

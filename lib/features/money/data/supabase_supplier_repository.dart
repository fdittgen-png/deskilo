// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/supplier.dart';

/// #2567 — the suppliers and their RPCs (0457). The supplier row carries no
/// bank data; the revisions are a separate table only managers can read.
class SupabaseSupplierRepository implements SupplierRepository {
  const SupabaseSupplierRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Supplier>> fetchSuppliers(String workspaceId) async {
    final rows = await _client
        .from('suppliers')
        .select(
          'id, supplier_number, name, tax_id_entered, tax_identifier, '
          'tax_id_kind, street, postal_code, city, country_code, contact, '
          'status, bank_revision',
        )
        .eq('workspace_id', workspaceId)
        .order('supplier_number');
    return [for (final r in rows) Supplier.fromRow(r)];
  }

  @override
  Future<List<SupplierReview>> fetchReviews(String workspaceId) async {
    final rows = await _client
        .from('supplier_review_candidates')
        .select(
          'id, reason, source_name, source_identifier, candidate_supplier_ids',
        )
        .eq('workspace_id', workspaceId)
        .eq('status', 'open')
        .order('created_datetime');
    return [for (final r in rows) SupplierReview.fromRow(r)];
  }

  @override
  Future<List<SupplierBankRevision>> fetchBankHistory(
    String workspaceId,
    String supplierId,
  ) async {
    final rows = await _client
        .from('supplier_bank_revisions')
        .select(
          'revision, account_holder, iban, bic, validation, '
          'validation_detail, changed_at',
        )
        .eq('workspace_id', workspaceId)
        .eq('supplier_id', supplierId)
        .order('revision', ascending: false);
    return [for (final r in rows) SupplierBankRevision.fromRow(r)];
  }

  @override
  Future<String> save(String workspaceId, SupplierDraft draft) async {
    final id = await _client.rpc<Object?>(
      'save_supplier',
      params: {
        'p_workspace_id': workspaceId,
        'p_supplier_id': draft.id,
        'p_name': draft.name,
        'p_tax_id': draft.taxId,
        'p_tax_id_kind': draft.taxIdKind.wire,
        'p_street': draft.street,
        'p_postal_code': draft.postalCode,
        'p_city': draft.city,
        'p_country_code': draft.countryCode,
        'p_contact': draft.contact,
        'p_number': draft.number,
      },
    );
    return id! as String;
  }

  @override
  Future<void> setStatus(String supplierId, SupplierStatus status) async {
    await _client.rpc<Object?>(
      'set_supplier_status',
      params: {'p_supplier_id': supplierId, 'p_status': status.name},
    );
  }

  @override
  Future<int> setBank(
    String supplierId, {
    required String accountHolder,
    required String iban,
    required String bic,
  }) async {
    final revision = await _client.rpc<Object?>(
      'set_supplier_bank',
      params: {
        'p_supplier_id': supplierId,
        'p_account_holder': accountHolder,
        'p_iban': iban,
        'p_bic': bic,
      },
    );
    return (revision! as num).toInt();
  }

  @override
  Future<String> resolveReview(String reviewId, String? supplierId) async {
    final id = await _client.rpc<Object?>(
      'resolve_supplier_review',
      params: {'p_candidate_id': reviewId, 'p_supplier_id': supplierId},
    );
    return id! as String;
  }
}

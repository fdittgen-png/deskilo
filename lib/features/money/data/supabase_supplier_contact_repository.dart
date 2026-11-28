// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4518 -- the contacts, the contact roles and the terms of the suppliers, read from their tables and kept through the commands (1003).
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/paged_fetch.dart';
import '../../../core/data/server_names.dart';
import '../domain/supplier_contact.dart';

class SupabaseSupplierContactRepository implements SupplierContactRepository {
  SupabaseSupplierContactRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<SupplierContactRole>> roles(String workspaceId) async {
    final rows = await fetchAllPages(table: 'supplier_contact_roles', build: () => _client.from('supplier_contact_roles')
        .select('id, code, label, sort_order, built_in, retired_at')
        .eq('workspace_id', workspaceId)
        .order('sort_order', ascending: true)
        .order('code', ascending: true));
    return [for (final row in rows) SupplierContactRole.fromJson(row)];
  }

  @override
  Future<List<SupplierContact>> contacts(String workspaceId, String supplierId) async {
    final rows = await fetchAllPages(table: 'supplier_contacts', build: () => _client.from('supplier_contacts')
        .select('id, supplier_id, name, role_id, email, phone, note, preferred, retired_at')
        .eq('workspace_id', workspaceId)
        .eq('supplier_id', supplierId)
        .order('name', ascending: true)
        .order('id', ascending: true));
    return [for (final row in rows) SupplierContact.fromJson(row)];
  }

  @override
  Future<SupplierTerms> terms(String workspaceId, String supplierId) async {
    final row = await _client.from(ServerTable.suppliers)
        .select('order_currency, payment_term_days, order_lead_days')
        .eq('workspace_id', workspaceId)
        .eq('id', supplierId)
        .maybeSingle();
    return row == null ? SupplierTerms.none : SupplierTerms.fromJson(row);
  }

  @override
  Future<void> saveRole(String workspaceId, {String? id, required String label, int? sortOrder, required String requestId}) async {
    await _client.rpc<Object?>('supplier_contact_role_save_v1', params: {
      'p_workspace_id': workspaceId,
      'p_request_id': requestId,
      'p_role': <String, Object?>{'id': ?id, 'label': label, 'sort_order': ?sortOrder},
    });
  }

  @override
  Future<void> setRoleRetired(String workspaceId, String id, {required bool retired, required String requestId}) async {
    await _client.rpc<Object?>('supplier_contact_role_retire_v1', params: {
      'p_workspace_id': workspaceId,
      'p_request_id': requestId,
      'p_id': id,
      'p_retired': retired,
    });
  }

  @override
  Future<void> saveContact(
    String workspaceId, {
    String? id,
    required String supplierId,
    required String name,
    required String roleId,
    required String email,
    required String phone,
    required String note,
    required bool preferred,
    required String requestId,
  }) async {
    await _client.rpc<Object?>('supplier_contact_save_v1', params: {
      'p_workspace_id': workspaceId,
      'p_request_id': requestId,
      'p_contact': <String, Object?>{
        'id': ?id,
        'supplier_id': supplierId,
        'name': name,
        'role_id': roleId,
        'email': email,
        'phone': phone,
        'note': note,
        'preferred': preferred,
      },
    });
  }

  @override
  Future<void> setContactRetired(String workspaceId, String id, {required bool retired, required String requestId}) async {
    await _client.rpc<Object?>('supplier_contact_retire_v1', params: {
      'p_workspace_id': workspaceId,
      'p_request_id': requestId,
      'p_id': id,
      'p_retired': retired,
    });
  }

  @override
  Future<void> saveTerms(String workspaceId, String supplierId, SupplierTerms terms, {required String requestId}) async {
    await _client.rpc<Object?>('save_supplier_terms_v1', params: {
      'p_workspace_id': workspaceId,
      'p_request_id': requestId,
      'p_supplier_id': supplierId,
      'p_terms': <String, Object?>{
        'order_currency': terms.orderCurrency,
        'payment_term_days': terms.paymentTermDays,
        'order_lead_days': terms.orderLeadDays,
      },
    });
  }
}

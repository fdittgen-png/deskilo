// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 (part 2) — my groups of invoices, read and written on my personal
// home, directly under row security (0801): my own rows only.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/codes/pg_code.dart';
import '../../../core/data/paged_fetch.dart';
import '../domain/invoice_groups.dart';

class SupabaseInvoiceGroupRepository implements InvoiceGroupRepository {
  SupabaseInvoiceGroupRepository(this._client);

  final SupabaseClient _client;

  static const _groups = 'personal_invoice_groups';
  static const _items = 'personal_invoice_group_items';

  @override
  Future<List<InvoiceGroup>> groups() async {
    final rows = await fetchConfigurationList(table: _groups, build: () => _client
        .from(_groups)
        .select('id, name, items:$_items(network_id, invoice_id, label)')
        .order('name', ascending: true)
        .order('id', ascending: true));
    return [for (final row in rows) InvoiceGroup.fromJson(row)];
  }

  @override
  Future<String> create(String name) => _named(() async {
    final row = await _client
        .from(_groups)
        .insert({'name': name})
        .select('id')
        .single();
    return row['id'] as String;
  });

  @override
  Future<void> rename(String groupId, String name) => _named(
    () => _client.from(_groups).update({'name': name}).eq('id', groupId),
  );

  @override
  Future<void> delete(String groupId) =>
      _client.from(_groups).delete().eq('id', groupId);

  @override
  Future<void> add(String groupId, InvoiceRef ref, String number) => _client
      .from(_items)
      .upsert(
        {
          'group_id': groupId,
          'network_id': ref.networkId,
          'invoice_id': ref.invoiceId,
          'label': number.length > invoiceGroupNumberMax
              ? number.substring(0, invoiceGroupNumberMax)
              : number,
        },
        onConflict: 'group_id,network_id,invoice_id',
        ignoreDuplicates: true,
      );

  @override
  Future<void> remove(String groupId, InvoiceRef ref) => _client
      .from(_items)
      .delete()
      .eq('group_id', groupId)
      .eq('network_id', ref.networkId)
      .eq('invoice_id', ref.invoiceId);

  /// A name the table refuses, as the refusal the form shows.
  Future<T> _named<T>(Future<T> Function() write) async {
    try {
      return await write();
    } on PostgrestException catch (e, st) {
      // trace-exempt: rethrown as the refusal the sheet names, or as is
      final refusal = switch (e.code) {
        PgCode.uniqueViolation => InvoiceGroupRefusal.nameTaken,
        '23514' => InvoiceGroupRefusal.nameShape,
        _ => null,
      };
      if (refusal == null) rethrow;
      Error.throwWithStackTrace(InvoiceGroupRefused(refusal), st);
    }
  }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4433 -- the items a business keeps in stock and has on sale, read for the invoice composer.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/paged_fetch.dart';
import '../../../core/data/server_names.dart';
import '../domain/invoice_goods.dart';

class SupabaseInvoiceGoodsCatalogue implements InvoiceGoodsCatalogue {
  SupabaseInvoiceGoodsCatalogue(this._client);

  final SupabaseClient _client;

  @override
  Future<List<InvoiceGoodsItem>> items(String workspaceId) async {
    final rows = await fetchAllPages(table: ServerTable.services, build: () => _client.from(ServerTable.services)
        .select('id, name, inventory_unit, tracking')
        .eq('workspace_id', workspaceId)
        .eq('stockable', true)
        .eq('active', true)
        .order('name')
        .order('id'));
    return [for (final row in rows) InvoiceGoodsItem.fromJson(row)];
  }
}

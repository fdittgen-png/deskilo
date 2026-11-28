// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4510 -- the business's active services that are not kept in stock, for the service picker of a quote or invoice line.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/paged_fetch.dart';
import '../../../core/data/server_names.dart';
import '../domain/invoice_services.dart';

class SupabaseInvoiceServiceCatalogue implements InvoiceServiceCatalogue {
  SupabaseInvoiceServiceCatalogue(this._client);

  final SupabaseClient _client;

  @override
  Future<List<InvoiceService>> services(String workspaceId) async {
    final rows = await fetchAllPages(table: ServerTable.services, build: () => _client.from(ServerTable.services)
        .select('id, name, price_cents, vat_rate_id, supply_class')
        .eq('workspace_id', workspaceId)
        .eq('stockable', false)
        .eq('active', true)
        .order('name', ascending: true)
        .order('id', ascending: true));
    return [for (final row in rows) InvoiceService.fromJson(row)];
  }
}

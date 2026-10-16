// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/tax_reporting_repository.dart';
import '../domain/vat_declaration.dart';
import '../domain/vat_rate.dart';

/// #2591 C3 — VAT rates and returns, with their own client. The bodies are
/// the ones that lived in the money repository's part files.
class SupabaseTaxReportingRepository implements TaxReportingRepository {
  SupabaseTaxReportingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<VatDeclaration>> fetchVatDeclarations(String workspaceId) async {
    final rows = await _client
        .from('vat_declarations')
        .select()
        .eq('workspace_id', workspaceId)
        .order('period_start', ascending: false);
    return rows.map(VatDeclaration.fromRow).toList();
  }

  @override
  Future<String> saveVatDeclaration({
    required String workspaceId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    // #2357 — the period alone: the server computes the figures.
    final id = await _client.rpc<dynamic>(
      'save_vat_declaration',
      params: {
        'p_workspace_id': workspaceId,
        'p_period_start': periodStart.toIso8601String().substring(0, 10),
        'p_period_end': periodEnd.toIso8601String().substring(0, 10),
      },
    );
    return id as String;
  }

  @override
  Future<void> markVatDeclarationSubmitted({
    required String declarationId,
    required String channel,
    required String receipt,
  }) async {
    await _client.rpc<void>(
      'mark_vat_declaration_submitted',
      params: {
        'p_declaration_id': declarationId,
        'p_channel': channel,
        'p_receipt': receipt,
      },
    );
  }

  @override
  Future<List<VatRate>> fetchVatRates(String workspaceId) async {
    final rows = await _client
        .from('vat_rates')
        .select()
        .eq('workspace_id', workspaceId)
        .order('percent', ascending: false);
    return rows.map(VatRate.fromRow).toList();
  }

  @override
  Future<void> setVatRates(String workspaceId, List<VatRate> rates) async {
    await _client.rpc<void>(
      'set_vat_rates',
      params: {
        'p_workspace_id': workspaceId,
        'p_rates': [for (final rate in rates) rate.toJson()],
      },
    );
  }
}

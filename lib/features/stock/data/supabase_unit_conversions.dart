// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/unit_conversions.dart';
import 'stock_rpc.dart';

/// #4479 -- the business's general conversions behind the port: the rows under the business's own row security and the two commands
/// that maintain them (0968). A refusal arrives as the stock configuration's typed failure; an answer of the wrong shape throws,
/// it is never shown as "no conversions".
class SupabaseUnitConversions implements UnitConversions {
  SupabaseUnitConversions(this._client);

  final SupabaseClient _client;

  StockRpc get _rpc => StockRpc(_client);

  @override
  Future<List<UnitConversion>> conversions(String workspaceId) async {
    final rows = await _rpc.rows(
      'unit_conversions',
      () => _client
          .from('unit_conversions')
          .select('from_unit, to_unit, factor_num, factor_den, authored, needs_review')
          .eq('workspace_id', workspaceId)
          .order('from_unit', ascending: true)
          .order('to_unit', ascending: true),
    );
    return [for (final row in rows) UnitConversion.fromJson(row)];
  }

  @override
  Future<UnitConversion> save(String workspaceId, {required String requestId, required UnitConversion conversion}) async => UnitConversion.fromJson(
    await _rpc.object('unit_conversion_save_v1', {
      'p_workspace_id': workspaceId,
      'p_request_id': requestId,
      'p_conversion': {
        'from_unit': conversion.fromUnit,
        'to_unit': conversion.toUnit,
        'factor_num': conversion.factorNum,
        'factor_den': conversion.factorDen,
      },
    }),
  );

  @override
  Future<void> delete(String workspaceId, {required String requestId, required String fromUnit, required String toUnit}) async {
    await _rpc.object('unit_conversion_delete_v1', {
      'p_workspace_id': workspaceId,
      'p_request_id': requestId,
      'p_from': fromUnit,
      'p_to': toUnit,
    });
  }
}

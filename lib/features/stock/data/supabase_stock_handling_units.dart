// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/handling_units.dart';
import 'stock_rpc.dart';

/// #4435 -- the handling unit functions (0928-0930) behind the port. A command answers the unit as it is after it; a refusal is
/// the typed `StockUnitRefused` (the unit changed, its content does not fit, its code is taken) or the stock path's own.
class SupabaseStockHandlingUnits implements StockHandlingUnits {
  SupabaseStockHandlingUnits(this._client);

  final SupabaseClient _client;

  StockRpc get _rpc => StockRpc(_client);

  @override
  Future<HandlingUnitPage> page(String workspaceId, {String? locationId, HandlingUnitState state = HandlingUnitState.open, Map<String, Object?>? after}) async {
    final answer = await _rpc.object('stock_hu_page_v1', {
      'p_workspace_id': workspaceId,
      'p_location_id': locationId,
      'p_state': state.name,
      'p_limit': 100,
      'p_after': after,
    });
    final r = JsonReader.of(answer, context: 'stock_hu_page_v1');
    return HandlingUnitPage(
      rows: [for (final row in r.requiredList('rows')) HandlingUnit.fromJson(row)],
      next: r.objectOrNull('next')?.json == null ? null : Map<String, Object?>.from(r.objectOrNull('next')!.json),
    );
  }

  @override
  Future<HandlingUnitDetail?> unit(String workspaceId, String unitId) async {
    final answer = await _rpc.object('stock_hu_v1', {'p_workspace_id': workspaceId, 'p_unit_id': unitId});
    final r = JsonReader.of(answer, context: 'stock_hu_v1');
    final unit = r.objectOrNull('unit');
    if (unit == null) return null;
    final location = r.stringOr('location_code');
    final base = HandlingUnit.fromJson(unit.json);
    return HandlingUnitDetail(
      unit: HandlingUnit(
        id: base.id,
        code: base.code,
        labelCode: base.labelCode,
        kind: base.kind,
        state: base.state,
        locationId: base.locationId,
        locationCode: location,
        parentUnitId: base.parentUnitId,
        revision: base.revision,
      ),
      lines: [for (final l in r.requiredList('lines')) HandlingUnitLine.fromJson(l)],
      children: [for (final c in r.requiredList('children')) HandlingUnit.fromJson(c)],
    );
  }

  Future<HandlingUnit> _unitOf(Map<String, Object?> answer, String fn) =>
      Future.value(HandlingUnit.fromJson((JsonReader.of(answer, context: fn).objectOrNull('unit') ?? (throw FormatException('$fn answered no unit'))).json));

  @override
  Future<HandlingUnit> make(String workspaceId, String requestId, UnitDraft draft) async => _unitOf(
        await _rpc.object('stock_hu_make_v1', {'p_workspace_id': workspaceId, 'p_request_id': requestId, 'p_unit': draft.toJson()}),
        'stock_hu_make_v1',
      );

  @override
  Future<HandlingUnit> move(String workspaceId, String requestId, {required String unitId, required String toLocationId, required int revision}) async => _unitOf(
        await _rpc.object('stock_hu_move_v1', {
          'p_workspace_id': workspaceId,
          'p_request_id': requestId,
          'p_unit_id': unitId,
          'p_to': toLocationId,
          'p_revision': revision,
        }),
        'stock_hu_move_v1',
      );

  @override
  Future<HandlingUnit> unpack(String workspaceId, String requestId, {required String unitId, required int revision}) async => _unitOf(
        await _rpc.object('stock_hu_unpack_v1', {
          'p_workspace_id': workspaceId,
          'p_request_id': requestId,
          'p_unit_id': unitId,
          'p_revision': revision,
        }),
        'stock_hu_unpack_v1',
      );

  @override
  Future<List<HandlingUnit>> repack(String workspaceId, String requestId, {required List<RepackSource> sources, required List<UnitDraft> targets}) async {
    final answer = await _rpc.object('stock_hu_repack_v1', {
      'p_workspace_id': workspaceId,
      'p_request_id': requestId,
      'p_sources': [for (final s in sources) s.toJson()],
      'p_targets': [for (final t in targets) t.toJson()],
    });
    return [for (final u in JsonReader.of(answer, context: 'stock_hu_repack_v1').requiredList('units')) HandlingUnit.fromJson(u)];
  }

  @override
  Future<LotUnitTrace> lotTrace(String workspaceId, {required String itemId, required String lotId}) async {
    final answer = await _rpc.object('stock_hu_lot_trace_v1', {'p_workspace_id': workspaceId, 'p_item_id': itemId, 'p_lot_id': lotId});
    final r = JsonReader.of(answer, context: 'stock_hu_lot_trace_v1');
    return LotUnitTrace(
      held: [
        for (final h in r.requiredList('held'))
          (
            unitId: JsonReader.of(h, context: 'held').string('unit_id'),
            code: JsonReader.of(h, context: 'held').string('code'),
            locationId: JsonReader.of(h, context: 'held').string('location_id'),
            quantity: ExactQuantity.parse(JsonReader.of(h, context: 'held').string('quantity')),
          ),
      ],
      repacks: [
        for (final x in r.requiredList('repacks'))
          (
            repackId: JsonReader.of(x, context: 'repacks').string('repack_id'),
            madeAt: DateTime.parse(JsonReader.of(x, context: 'repacks').string('made_at')),
            direction: JsonReader.of(x, context: 'repacks').string('direction'),
            code: JsonReader.of(x, context: 'repacks').stringOrNull('code'),
            quantity: ExactQuantity.parse(JsonReader.of(x, context: 'repacks').string('quantity')),
            pieceId: JsonReader.of(x, context: 'repacks').stringOrNull('piece_id'),
          ),
      ],
    );
  }
}

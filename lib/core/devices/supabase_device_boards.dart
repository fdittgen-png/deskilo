// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4454 -- the till boards on the server: the owner's functions of migration 0984. A refusal comes back as the
// contract's reason (TillBoardRefused); anything else is the read's failure.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../trace/trace_logger.dart';
import 'device_board.dart';
import 'device_code.dart';

class SupabaseTillBoards implements TillBoardPort {
  const SupabaseTillBoards(this._client);

  final SupabaseClient _client;

  Future<Object?> _call(String fn, Map<String, Object?> params) async {
    try {
      return await _client.rpc<Object?>(fn, params: params);
    } on PostgrestException catch (e, st) {
      final refusal = _refusalOf(e);
      TraceLogger.instance.log(TraceLevel.info, 'till', 'a till board command ($fn): ${refusal ?? e.code}', error: e, stackTrace: st);
      if (refusal == null) rethrow;
      throw TillBoardRefused(refusal);
    }
  }

  static TillBoardRefusal? _refusalOf(PostgrestException e) {
    if (e.code == '42501') return TillBoardRefusal.notAllowed;
    if (e.code != '22023') return null;
    final m = e.message;
    if (m.startsWith('scope_mismatch')) return TillBoardRefusal.scope;
    if (m.startsWith('pair_used')) return TillBoardRefusal.used;
    return TillBoardRefusal.proof;
  }

  @override
  Future<List<TillBoard>> boards(String workspaceId) async {
    final rows = await _call('till_terminals_v1', {'p_workspace_id': workspaceId});
    return [
      for (final row in rows is List ? rows : const <Object?>[])
        ?_board(row),
    ];
  }

  static TillBoard? _board(Object? row) {
    final r = JsonReader.of(row, context: 'till_terminals_v1');
    final status = TillBoardStatus.of(r.stringOrNull('status'));
    if (status == null) return null;
    final profileKey = r.stringOrNull('board_profile');
    return TillBoard(
      id: r.string('id'),
      tillId: r.string('till_id'),
      tillName: r.string('till_name'),
      deviceId: r.string('device_id'),
      profile: BoardProfile.values.where((p) => p.key == profileKey).firstOrNull,
      fingerprint: r.string('fingerprint'),
      firmware: r.string('firmware'),
      status: status,
    );
  }

  @override
  Future<TillBoardCode> code(String workspaceId, String tillId, DeviceCode scanned) async {
    final r = JsonReader.of(
      await _call('till_terminal_code_create_v1', {
        'p_workspace_id': workspaceId,
        'p_till_id': tillId,
        'p_device_id': scanned.id,
        'p_board_profile': scanned.profile.key,
        'p_secret_hash': scanned.secretHash,
      }),
      context: 'till_terminal_code_create_v1',
    );
    return TillBoardCode(id: r.string('code_id'), code: r.string('code'), expiresAt: DateTime.parse(r.string('expires_at')));
  }

  @override
  Future<bool> cancelCode(String codeId) async => await _call('till_terminal_code_cancel_v1', {'p_code_id': codeId}) == true;

  @override
  Future<void> approve(String boardId, String fingerprint) =>
      _call('till_terminal_approve_v1', {'p_terminal_id': boardId, 'p_fingerprint': fingerprint});

  @override
  Future<bool> revoke(String boardId) async => await _call('till_terminal_revoke_v1', {'p_terminal_id': boardId}) == true;
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4454 -- the till boards on the server: the owner's functions of migration 0984. A refusal comes back as the
// contract's reason (TillBoardRefused); anything else is the read's failure.
import 'dart:convert';

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../codes/dk_code.dart';
import '../data/app_failure_from.dart';
import '../failure/app_failure.dart';
import '../trace/trace_logger.dart';
import 'device_board.dart';
import 'device_code.dart';

class SupabaseTillBoards implements TillBoardPort {
  const SupabaseTillBoards(this._client);

  final SupabaseClient _client;

  Future<Object?> _call(String fn, Map<String, Object?> params) async {
    try {
      return await _client.rpc<Object?>(fn, params: params);
    } on Object catch (e, st) {
      final failure = appFailureFrom(e);
      TraceLogger.instance.log(TraceLevel.info, 'till', 'a till board command ($fn): $failure', error: e, stackTrace: st);
      final refusal = failure is Refusal ? _refusalOf(failure) : null;
      if (refusal == null) rethrow;
      Error.throwWithStackTrace(TillBoardRefused(refusal), st);
    }
  }

  /// The contract's reason for the server's refusal (0984: DKN01 not allowed, DKL02 with its reason), or null.
  static TillBoardRefusal? _refusalOf(Refusal r) => switch (r.code) {
    DkCode.dkn01 => TillBoardRefusal.notAllowed,
    DkCode.dkl02 => switch (_reason(r.details)) {
      'till' => TillBoardRefusal.scope,
      'used' => TillBoardRefusal.used,
      _ => TillBoardRefusal.proof,
    },
    _ => null,
  };

  /// The `reason` of a refusal's JSON detail, or empty: a detail that is not our JSON is no hint.
  static String _reason(String? details) {
    if (details == null) return '';
    try {
      return JsonReader.orEmpty(jsonDecode(details), context: 'till board refusal').stringOr('reason');
    } on Object catch (e, st) {
      TraceLogger.instance.log(TraceLevel.info, 'till', 'a refusal detail without a reason', error: e, stackTrace: st);
      return '';
    }
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

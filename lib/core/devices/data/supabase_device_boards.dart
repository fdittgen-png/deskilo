// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4454 -- the till boards on the server: the owner's functions of migration 0984. A refusal comes back as the
// contract's reason (TillBoardRefused); anything else is the read's failure.
import 'dart:convert';

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../codes/dk_code.dart';
import '../../data/app_failure_from.dart';
import '../../failure/app_failure.dart';
import '../../trace/trace_logger.dart';
import '../device_board.dart';
import '../device_code.dart';

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
    final lease = r.objectOrNull('lease');
    return TillBoard(
      id: r.string('id'),
      tillId: r.string('till_id'),
      tillName: r.string('till_name'),
      deviceId: r.string('device_id'),
      profile: BoardProfile.values.where((p) => p.key == profileKey).firstOrNull,
      fingerprint: r.string('fingerprint'),
      firmware: r.stringOr('firmware'),
      status: status,
      cashierAsked: r.boolOr('cashier_asked', fallback: false),
      lease: lease == null
          ? null
          : TillBoardLease(
              id: lease.string('id'),
              memberName: lease.stringOr('member_name'),
              expiresAt: DateTime.parse(lease.string('expires_at')),
              mine: r.boolOr('mine', fallback: false),
            ),
    );
  }

  @override
  Future<List<TillBoard>> cashierBoards(String workspaceId) async {
    final rows = await _call('till_terminal_cashier_boards_v1', {'p_workspace_id': workspaceId});
    return [
      for (final row in rows is List ? rows : const <Object?>[])
        ?_cashierBoard(row),
    ];
  }

  /// A row of the cashiers' list: a paired board, without its profile and firmware.
  static TillBoard? _cashierBoard(Object? row) {
    if (row is! Map) return null;
    return _board({...row, 'status': TillBoardStatus.paired.wire, 'board_profile': null, 'firmware': ''});
  }

  @override
  Future<DateTime> authorize(String boardId) async {
    final Object? data;
    try {
      data = (await _client.functions.invoke('embedded-till', body: {'action': 'operator.authorize', 'terminal_id': boardId})).data;
    } on FunctionException catch (e, st) {
      TraceLogger.instance.log(TraceLevel.info, 'till', 'a board was not authorized: ${e.status}', error: e, stackTrace: st);
      Error.throwWithStackTrace(TillBoardAuthorizeRefused(_authorizeRefusalOf(e.details)), st);
    }
    final r = JsonReader.of(data, context: 'embedded-till operator.authorize');
    if (r.boolOr('ok', fallback: false)) {
      return DateTime.parse(r.objectOrNull('result')?.string('expires_at') ?? r.string('expires_at'));
    }
    throw TillBoardAuthorizeRefused(_authorizeRefusalOf(data));
  }

  /// The words of a refused authorization: the edge function's reason, or the server's code and its detail's reason.
  static TillBoardAuthorizeRefusal _authorizeRefusalOf(Object? answer) {
    final r = JsonReader.orEmpty(answer is String ? _decoded(answer) : answer, context: 'embedded-till refusal');
    final code = r.stringOr('code');
    final detail = r.raw('detail');
    final reason = code.isEmpty ? r.stringOr('reason') : _reason(detail is String ? detail : null);
    return switch ((code, reason)) {
      (DkCode.dkn01, _) => TillBoardAuthorizeRefusal.notAllowed,
      (_, 'no_request') => TillBoardAuthorizeRefusal.noRequest,
      (_, 'device_revoked' || 'pair_pending' || 'terminal') => TillBoardAuthorizeRefusal.notPaired,
      (_, 'operator_token' || 'operator_revoked' || 'operator_expired') => TillBoardAuthorizeRefusal.signIn,
      (_, 'terminal_not_configured') => TillBoardAuthorizeRefusal.notConfigured,
      _ => TillBoardAuthorizeRefusal.uncertain,
    };
  }

  static Object? _decoded(String text) {
    try {
      return jsonDecode(text);
    } on Object catch (e, st) {
      TraceLogger.instance.log(TraceLevel.info, 'till', 'an answer that is not JSON', error: e, stackTrace: st);
      return null;
    }
  }

  @override
  Future<bool> endLease(String leaseId) async => await _call('till_terminal_lease_revoke_v1', {'p_lease_id': leaseId}) == true;

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

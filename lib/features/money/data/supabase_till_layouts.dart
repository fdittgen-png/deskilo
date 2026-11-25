// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4448 -- the till layouts on the server: the rows of `till_layouts` the person may read, and the two commands.
import 'dart:convert';

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/codes/dk_code.dart';
import '../../../core/data/app_failure_from.dart';
import '../../../core/failure/app_failure.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/till_layout.dart';
import '../domain/till_layout_port.dart';

/// The table of the till layouts.
const _tillLayoutsTable = 'till_layouts';

class SupabaseTillLayouts implements TillLayoutPort {
  const SupabaseTillLayouts(this._client);

  final SupabaseClient _client;

  Future<TillLayout?> _read(String workspaceId, String tillId, TillLayoutStatus status) async {
    final rows = await _client
        .from(_tillLayoutsTable)
        .select('name, version, status, layout')
        .eq('workspace_id', workspaceId)
        .eq('till_id', tillId)
        .eq('status', status.wire)
        .order('version', ascending: false)
        .limit(1);
    if ((rows as List).isEmpty) return null;
    final r = JsonReader.of(rows.first, context: _tillLayoutsTable);
    return TillLayout.fromJson(
      r.objectOrAbsent('layout').json,
      name: r.string('name'),
      version: r.intOrNull('version') ?? 0,
      status: TillLayoutStatus.of(r.string('status')),
    );
  }

  @override
  Future<TillLayout?> draft(String workspaceId, String tillId) => _read(workspaceId, tillId, TillLayoutStatus.draft);

  @override
  Future<TillLayout?> published(String workspaceId, String tillId) => _read(workspaceId, tillId, TillLayoutStatus.published);

  int _version(Object? answer) => JsonReader.of(answer, context: 'till_layout').intOrNull('version') ?? 0;

  /// The server's refusal as the editor reads it: the code decides, the detail's reason is kept for an invalid layout.
  Future<int> _command(Future<Object?> Function() call) async {
    try {
      return _version(await call());
    } on Object catch (e, st) {
      final failure = appFailureFrom(e);
      TraceLogger.instance.log(TraceLevel.info, 'till', 'a till layout command: $failure', error: e, stackTrace: st);
      if (failure is! Refusal) rethrow;
      final refused = switch (failure.code) {
        DkCode.dkl10 => const TillLayoutRefused(TillLayoutRefusalKind.stale),
        DkCode.dkl02 => TillLayoutRefused(TillLayoutRefusalKind.invalid, _reason(failure.details)),
        _ => TillLayoutRefused(TillLayoutRefusalKind.other, failure.code ?? ''),
      };
      Error.throwWithStackTrace(refused, st);
    }
  }

  /// The `reason` of a refusal's JSON detail, or empty: a detail that is not our JSON is no hint.
  String _reason(String? details) {
    if (details == null) return '';
    try {
      return JsonReader.orEmpty(jsonDecode(details), context: 'till_layout refusal').stringOr('reason');
    } on Object catch (e, st) {
      TraceLogger.instance.log(TraceLevel.info, 'till', 'a refusal detail without a reason', error: e, stackTrace: st);
      return '';
    }
  }

  @override
  Future<int> save(String workspaceId, {required String requestId, required String tillId, required TillLayout layout, required int expectedVersion}) async =>
      _command(() => _client.rpc('till_layout_save_v1', params: {
        'p_workspace_id': workspaceId,
        'p_request_id': requestId,
        'p_till_id': tillId,
        'p_name': layout.name,
        'p_expected_version': expectedVersion,
        'p_layout': layout.toJson(),
      }));

  @override
  Future<int> publish(String workspaceId, {required String requestId, required String tillId, required int expectedVersion}) async =>
      _command(() => _client.rpc('till_layout_publish_v1', params: {
        'p_workspace_id': workspaceId,
        'p_request_id': requestId,
        'p_till_id': tillId,
        'p_expected_version': expectedVersion,
      }));
}

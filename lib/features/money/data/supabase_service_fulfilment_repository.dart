// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4178 (F4) -- service fulfilment over the RPCs of 0852. A server refusal
// becomes a typed [FulfilmentRefusal]; a transport failure passes through
// untouched (a write is never retried here: the same request identity is what
// makes a retry safe, and the screen offers it).
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/dk_code.dart';
import '../../../core/data/pg_code.dart';
import '../../../core/data/unreadable_rows.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/service_fulfilment.dart';

class SupabaseServiceFulfilmentRepository
    implements ServiceFulfilmentRepository {
  const SupabaseServiceFulfilmentRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ServiceFulfilment>> fulfilments(String workspaceId) async {
    final rows = await _asRefusal(
      () => _client.rpc<Object?>(
        'service_fulfilments_v1',
        params: {'p_workspace_id': workspaceId},
      ),
    );
    if (rows is! List) return const [];
    final kept = <ServiceFulfilment>[];
    final left = <String, String>{};
    for (final row in rows) {
      try {
        kept.add(ServiceFulfilment.fromJson(row));
      } on UnknownFulfilmentState catch (e, st) {
        // the row is left out and counted, never read as a state it is not
        TraceLogger.instance.warn(
          'money',
          'an engagement was left out: unknown state ${e.wire}',
          error: e,
          stackTrace: st,
        );
        left[row is Map ? '${row['fulfilment_id']}' : '?'] = e.wire;
      }
    }
    UnreadableRows.instance.record(
      fulfilmentsArea,
      workspaceId,
      left,
      scope: workspaceId,
    );
    return kept;
  }

  @override
  Future<ServiceFulfilment> fulfilment(
    String workspaceId,
    String fulfilmentId,
  ) async => ServiceFulfilment.fromJson(
    await _asRefusal(
      () => _client.rpc<Object?>(
        'service_fulfilment_v1',
        params: {
          'p_workspace_id': workspaceId,
          'p_fulfilment_id': fulfilmentId,
        },
      ),
    ),
  );

  @override
  Future<ServiceFulfilment?> ofLine(
    String workspaceId, {
    required String kind,
    required String id,
    required String lineId,
  }) async {
    final row = await _asRefusal(
      () => _client.rpc<Object?>(
        'service_fulfilment_of_line_v1',
        params: {
          'p_workspace_id': workspaceId,
          'p_kind': kind,
          'p_id': id,
          'p_line_id': lineId,
        },
      ),
    );
    return row == null ? null : ServiceFulfilment.fromJson(row);
  }

  @override
  Future<FulfilmentOpened> openFromLine(
    String workspaceId, {
    required String requestId,
    required String kind,
    required String id,
    required String lineId,
  }) async => FulfilmentOpened.fromJson(
    await _asRefusal(
      () => _client.rpc<Object?>(
        'open_service_fulfilment_v1',
        params: {
          'p_workspace_id': workspaceId,
          'p_request_id': requestId,
          'p_source': {'kind': kind, 'id': id, 'line_id': lineId},
        },
      ),
    ),
  );

  @override
  Future<FulfilmentOpened> openDirect(
    String workspaceId, {
    required String requestId,
    required DirectEngagementInput input,
  }) async => FulfilmentOpened.fromJson(
    await _asRefusal(
      () => _client.rpc<Object?>(
        'open_service_fulfilment_v1',
        params: {
          'p_workspace_id': workspaceId,
          'p_request_id': requestId,
          'p_source': {'kind': 'direct'},
          'p_scope': input.toWire(),
        },
      ),
    ),
  );

  @override
  Future<ServiceFulfilment> transition(
    String workspaceId,
    String fulfilmentId, {
    required int expectedRevision,
    required FulfilmentState to,
    required String requestId,
    String reason = '',
  }) async {
    final answer = await _asRefusal(
      () => _client.rpc<Object?>(
        'transition_service_fulfilment_v1',
        params: {
          'p_workspace_id': workspaceId,
          'p_fulfilment_id': fulfilmentId,
          'p_expected_revision': expectedRevision,
          'p_to': to.wire,
          'p_reason': reason,
          'p_request_id': requestId,
        },
      ),
    );
    return ServiceFulfilment.fromJson(
      answer is Map ? answer['fulfilment'] : null,
    );
  }

  @override
  Future<ServiceFulfilment> linkInvoice(
    String workspaceId,
    String fulfilmentId, {
    required String invoiceId,
    required String lineId,
  }) async {
    final answer = await _asRefusal(
      () => _client.rpc<Object?>(
        'link_service_fulfilment_invoice_v1',
        params: {
          'p_workspace_id': workspaceId,
          'p_fulfilment_id': fulfilmentId,
          'p_invoice_id': invoiceId,
          'p_line_id': lineId,
        },
      ),
    );
    return ServiceFulfilment.fromJson(
      answer is Map ? answer['fulfilment'] : null,
    );
  }

  /// The server's refusals of 0852 by code: DKF02 stale (the detail is the
  /// current revision), DKF03 and DKF04 state, DKF05 a request used for
  /// something else, DKF06 an incomplete fact (the detail names it), DKF01
  /// unknown, DKF10 switched off, DKF07, 42501 and 28000 not allowed.
  Future<T> _asRefusal<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PostgrestException catch (e, st) {
      // trace-exempt: a refusal is rethrown typed with its cause and stack; a
      // failure that is not one passes through untouched.
      final kind = switch (e.code) {
        DkCode.dkf02 => FulfilmentRefusalKind.stale,
        DkCode.dkf03 || DkCode.dkf04 => FulfilmentRefusalKind.state,
        DkCode.dkf05 => FulfilmentRefusalKind.requestReused,
        DkCode.dkf06 => FulfilmentRefusalKind.incomplete,
        DkCode.dkf01 => FulfilmentRefusalKind.unknown,
        DkCode.dkf10 => FulfilmentRefusalKind.featureOff,
        DkCode.dkf07 || PgCode.insufficientPrivilege || PgCode.invalidAuthorization => FulfilmentRefusalKind.notAllowed,
        _ => null,
      };
      if (kind == null) rethrow;
      Error.throwWithStackTrace(
        FulfilmentRefusal(kind, detail: e.details?.toString() ?? ''),
        st,
      );
    }
  }
}

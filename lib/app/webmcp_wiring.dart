// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2504 — where the page's WebMCP registry meets the app: the conditions it
// registers under (who is signed in, which workspace, its features, the
// device switch) and the read tools it can answer. A tool is offered only
// when a runner here answers it; the rest of the contract waits for its
// runner (reads, then the writes with the in-app confirmation).
//
// A runner reads what the app's own screens read, through the same
// providers and repositories, never the MCP facade. Its answer carries only
// the fields the contract's `output` lists for the operation.
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/trace/trace_logger.dart';
import '../core/webmcp/webmcp_context.dart';
import '../core/webmcp/webmcp_device_switch.dart';
import '../core/webmcp/webmcp_registry.dart';
import '../core/webmcp/webmcp_tool_spec.dart';
import '../core/webmcp/webmcp_tools.g.dart';
import '../features/events/providers/event_providers.dart';
import '../features/money/providers/money_providers.dart';
import '../features/reservations/domain/reservation.dart';
import '../features/reservations/providers/place_feedback_providers.dart';
import '../features/reservations/providers/reservation_providers.dart';
import '../features/workspace/domain/workspace_feature.dart';
import '../features/workspace/providers/workspace_providers.dart';

/// What decides whether the page offers tools, as the app knows it now.
final _conditionsProvider = Provider<WebMcpConditions>((ref) {
  final features = ref.watch(enabledFeaturesSyncProvider);
  return WebMcpConditions(
    accountId: ref.watch(currentAccountIdProvider),
    workspaceId: ref.watch(currentWorkspaceProvider).value?.id,
    featureEnabled: features.contains(WorkspaceFeature.webMcp),
    deviceSwitchOn: ref.watch(webMcpDeviceSwitchProvider).value ?? false,
    enabledFeatureKeys: {for (final f in features) f.dbKey},
  );
});

/// The browser's `modelContext` (a stand-in that offers nothing outside
/// the web build).
@visibleForTesting
final webMcpContextProvider = Provider<WebMcpContext>(
  (ref) => browserWebMcpContext(),
);

/// The page's registry, kept in line with [_conditionsProvider]: the
/// shell watches it, so it lives as long as the signed-in app does.
final webMcpRegistryProvider = Provider<WebMcpRegistry>((ref) {
  late final WebMcpRegistry registry;
  registry = WebMcpRegistry(
    context: ref.watch(webMcpContextProvider),
    runner: (tool, input, conditions) => _runRead(
      ref,
      tool,
      input,
      conditions,
      offered: () => registry.registeredNames,
    ),
    tools: [
      for (final tool in webMcpTools)
        if (webMcpReadRunners.containsKey(tool.id)) tool,
    ],
  );
  ref
    ..onDispose(registry.dispose)
    ..listen(
      _conditionsProvider,
      (_, next) => registry.update(next),
      fireImmediately: true,
    );
  return registry;
});

typedef WebMcpRead = Future<Map<String, Object?>> Function(
  Ref ref,
  Map<String, Object?> input,
  WebMcpConditions conditions,
  List<String> Function() offered,
);

/// The read operations the page answers, by contract operation id.
@visibleForTesting
final Map<String, WebMcpRead> webMcpReadRunners = {
  'list_workspaces': _listWorkspaces,
  'list_my_reservations': _listMyReservations,
  'list_my_invoices': _listMyInvoices,
  'list_pending_validations': _listPendingValidations,
  'list_my_favorites': _listMyFavorites,
  'get_my_statement': _getMyStatement,
};

/// Runs [tool] and wraps its answer as the MCP facade does: a status, the
/// operation, the workspace and its output; or the refusal it ran into.
Future<Object?> _runRead(
  Ref ref,
  WebMcpToolSpec tool,
  Map<String, Object?> input,
  WebMcpConditions conditions, {
  required List<String> Function() offered,
}) async {
  final read = webMcpReadRunners[tool.id];
  if (read == null) {
    return _refusal('unavailable', 'This tool is not offered here.');
  }
  try {
    final output = await read(ref, input, conditions, offered);
    return {
      'ok': true,
      'status': 'completed',
      'operation': tool.id,
      if (tool.scope != 'discovery') 'workspace_id': conditions.workspaceId,
      'output': output,
    };
  } on _Refused catch (r, st) {
    TraceLogger.instance.warn(
      'webmcp',
      '${tool.id} refused: ${r.code}',
      stackTrace: st,
    );
    return _refusal(r.code, r.message);
  }
}

Map<String, Object?> _refusal(String code, String message) => {
  'ok': false,
  'error': {'code': code, 'message': message},
};

/// A refusal of the input, said to the agent in the facade's words.
class _Refused implements Exception {
  const _Refused(this.code, this.message);
  final String code;
  final String message;
}

int _limit(Map<String, Object?> input) {
  final raw = input['limit'] ?? 25;
  if (raw is! int || raw < 1 || raw > 100) {
    throw const _Refused(
      'validation_error',
      'limit must be an integer from 1 to 100.',
    );
  }
  return raw;
}

/// Where a page starts: the cursor is this page's own (an offset), opaque
/// to the agent and refused when it was not one of ours.
int _offset(Map<String, Object?> input) {
  final raw = input['cursor'];
  if (raw == null) return 0;
  try {
    final decoded = utf8.decode(base64Url.decode(raw as String));
    final offset = int.parse(decoded.substring('page:'.length));
    if (!decoded.startsWith('page:') || offset < 0) {
      throw const FormatException();
    }
    return offset;
  } on Object catch (e, st) {
    // An agent's malformed cursor is answered as a refusal, not logged.
    Error.throwWithStackTrace(
      const _Refused(
        'validation_error',
        'cursor is not one this page handed out.',
      ),
      st,
    );
  }
}

/// One page of [rows] and the cursor of the next one (null at the end).
Map<String, Object?> _page(
  List<Map<String, Object?>> rows,
  Map<String, Object?> input,
) {
  final limit = _limit(input);
  final offset = _offset(input);
  final page = rows.skip(offset).take(limit).toList();
  final next = offset + page.length;
  return {
    'items': page,
    'next_cursor': next < rows.length
        ? base64Url.encode(utf8.encode('page:$next'))
        : null,
  };
}

DateTime _time(Map<String, Object?> input, String name) {
  final raw = input[name];
  final parsed = raw is String ? DateTime.tryParse(raw) : null;
  if (parsed == null) {
    throw _Refused(
      'validation_error',
      '$name must be an ISO 8601 time with an offset.',
    );
  }
  return parsed;
}

Future<Map<String, Object?>> _listWorkspaces(
  Ref ref,
  Map<String, Object?> input,
  WebMcpConditions conditions,
  List<String> Function() offered,
) async {
  _limit(input);
  // The page acts in its own workspace only: that is the one to offer.
  final workspace = await ref.read(currentWorkspaceProvider.future);
  return {
    'workspaces': [
      if (workspace != null)
        {
          'workspace_id': workspace.id,
          'name': workspace.name,
          'operations': offered(),
        },
    ],
    'has_more': false,
  };
}

Future<Map<String, Object?>> _listMyReservations(
  Ref ref,
  Map<String, Object?> input,
  WebMcpConditions conditions,
  List<String> Function() offered,
) async {
  final from = _time(input, 'from');
  final to = _time(input, 'to');
  if (!to.isAfter(from) || to.difference(from) > const Duration(days: 31)) {
    throw const _Refused(
      'validation_error',
      'to must be after from, at most 31 days later.',
    );
  }
  final workspace = await ref.read(currentWorkspaceProvider.future);
  final me = await ref.read(myMemberProvider.future);
  if (workspace == null || me == null) {
    throw const _Refused(
      'not_a_member',
      'This person is not a member of this workspace.',
    );
  }
  final window = await ref
      .read(reservationRepositoryProvider)
      .fetchWindow(workspace.id, from: from, to: to);
  final mine = [
    for (final r in window)
      if (r.memberId == me.id) r,
  ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return _page([
    for (final r in mine)
      {
        'reservation_id': r.id,
        'seat_id': r.seatId,
        'desk_id': r.deskId,
        'office_id': r.officeId,
        'level_id': r.levelId,
        'starts_at': r.startsAt.toUtc().toIso8601String(),
        'ends_at': r.endsAt.toUtc().toIso8601String(),
        'status': reservationStatusToDb(r.status),
      },
  ], input);
}

Future<Map<String, Object?>> _listMyInvoices(
  Ref ref,
  Map<String, Object?> input,
  WebMcpConditions conditions,
  List<String> Function() offered,
) async {
  final me = await ref.read(myMemberProvider.future);
  if (me == null) {
    throw const _Refused(
      'not_a_member',
      'This person is not a member of this workspace.',
    );
  }
  // An administrator's list holds everyone's: "my invoices" are the
  // person's own, as the facade answers them.
  final invoices = await ref.read(memberInvoicesProvider(me.id).future);
  return _page([
    for (final i in invoices)
      {
        'invoice_id': i.id,
        'number': i.number,
        'period': i.period,
        'kind': i.kind.name,
        'total_cents': i.totalCents,
        'currency': i.currency,
        'issued_at': i.issuedAt.toUtc().toIso8601String(),
        'voided': i.isVoided,
      },
  ], input);
}

Future<Map<String, Object?>> _listPendingValidations(
  Ref ref,
  Map<String, Object?> input,
  WebMcpConditions conditions,
  List<String> Function() offered,
) async {
  final me = await ref.read(myMemberProvider.future);
  if (me == null) {
    throw const _Refused(
      'not_a_member',
      'This person is not a member of this workspace.',
    );
  }
  final pending = [...await ref.read(myPendingEventsProvider.future)]
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return _page([
    for (final e in pending)
      {
        'event_id': e.id,
        'type': e.type.dbName,
        'requested_at': e.createdAt.toUtc().toIso8601String(),
        'mine': e.actorMemberId == me.id || e.subjectMemberId == me.id,
      },
  ], input);
}

Future<Map<String, Object?>> _listMyFavorites(
  Ref ref,
  Map<String, Object?> input,
  WebMcpConditions conditions,
  List<String> Function() offered,
) async {
  final favorites = await ref.read(myFavoritePlacesProvider.future);
  return {
    'items': [
      for (final f in favorites)
        {
          'kind': f.kind.name,
          'resource_id': f.id,
          'label': f.label,
          'favorite': f.feedback.favorite,
          'average': f.feedback.average,
          'count': f.feedback.count,
          'mine': f.feedback.mine,
        },
    ],
  };
}

final _month = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');

Future<Map<String, Object?>> _getMyStatement(
  Ref ref,
  Map<String, Object?> input,
  WebMcpConditions conditions,
  List<String> Function() offered,
) async {
  final period = input['period'];
  if (period is! String || !_month.hasMatch(period)) {
    throw const _Refused(
      'validation_error',
      'period must be a month, YYYY-MM.',
    );
  }
  final workspace = await ref.read(currentWorkspaceProvider.future);
  final statement = await ref.read(myStatementProvider(period).future);
  if (workspace == null || statement == null) {
    throw const _Refused(
      'not_a_member',
      'This person is not a member of this workspace.',
    );
  }
  return {
    'period': statement.period,
    'subscription_pct': statement.subscriptionPct,
    'fee_cents': statement.feeCents,
    'included_half_days': statement.includedHalfDays,
    'granted_half_days': statement.grantedHalfDays,
    'open_days': statement.openDays,
    'used_half_days': statement.usedHalfDays,
    'extra_half_days': statement.extraHalfDays,
    'overage_rate_cents': statement.overageRateCents,
    'overage_cents': statement.overageCents,
    'credits_cents': statement.creditsCents,
    'balance_cents': statement.balanceCents,
    'desk_supplement_cents': statement.deskSupplementCents,
    'office_supplement_cents': statement.officeSupplementCents,
    'level_supplement_cents': statement.levelSupplementCents,
    'accessory_supplement_cents': statement.accessorySupplementCents,
    'currency': workspace.currencyCode,
  };
}

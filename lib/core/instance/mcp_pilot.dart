// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1633 — the bounded, read-only pilot after a controlled activation: one
// `tools/list` and one `get_capabilities` call, made with a pilot user's
// own delegated token through the deployed endpoint. It proves what the
// disabled inspection could not: that the endpoint serves THIS installation's
// catalogue, that the answer comes back for the workspace asked about, and
// that the answer carries only fields the contract classifies. It never
// calls anything that writes, and it keeps no field VALUE: the verdict is
// codes and counts.
import 'mcp_readiness.dart';

/// The one operation the pilot calls: read-only, workspace-scoped, and
/// answering the caller's own capabilities rather than anybody's data.
const mcpPilotOperation = 'get_capabilities';

/// Checks over what the endpoint answered. [toolsList] and [call] are the
/// decoded JSON-RPC responses (null = no answer).
List<ReadinessCheck> evaluateMcpPilot({
  required Map<String, Object?> catalogue,
  required String workspaceId,
  required Object? toolsList,
  required Object? call,
}) {
  const area = ReadinessArea.mcpRuntime;
  ReadinessCheck check(
    String code,
    bool ok,
    String failDetail, [
    String passDetail = '',
  ]) => ReadinessCheck(
    area,
    code,
    ok ? CheckOutcome.pass : CheckOutcome.fail,
    ok ? passDetail : failDetail,
  );
  final ops =
      (catalogue['operations'] as Map?)?.cast<String, Object?>() ?? const {};
  final checks = <ReadinessCheck>[];

  final pilotOp = ops[mcpPilotOperation];
  checks.add(
    check(
      'pilot_operation_read_only',
      pilotOp is Map && pilotOp['mutation'] == 'read',
      '$mcpPilotOperation is not a read in this catalogue; the pilot refuses to run it',
    ),
  );

  final tools = _result(toolsList)?['tools'];
  if (tools is! List) {
    checks.add(
      const ReadinessCheck(
        area,
        'pilot_tools_listed',
        CheckOutcome.fail,
        'tools/list did not answer a tool list',
      ),
    );
  } else {
    final names = [
      for (final t in tools)
        if (t is Map) '${t['name']}',
    ];
    checks.add(
      check(
        'pilot_tools_listed',
        names.isNotEmpty,
        'the pilot user is offered no tool',
        '${names.length} tool(s)',
      ),
    );
    final unknown = names.where(
      (n) => !n.startsWith('deskilo_') || !ops.containsKey(n.substring(8)),
    );
    checks.add(
      check(
        'pilot_tools_known',
        unknown.isEmpty,
        '${unknown.length} offered tool(s) are not in this installation\'s catalogue',
      ),
    );
    final wrongHint = [
      for (final t in tools)
        if (t is Map &&
            ops[_opOf(t)] is Map &&
            ((t['annotations'] as Map?)?['readOnlyHint'] == true) !=
                ((ops[_opOf(t)] as Map)['mutation'] == 'read'))
          t['name'],
    ];
    checks.add(
      check(
        'pilot_read_only_hints',
        wrongHint.isEmpty,
        '${wrongHint.length} tool(s) are annotated read-only when they write, or the reverse',
      ),
    );
  }

  final result = _result(call);
  final envelope = result?['structuredContent'];
  if (result == null || result['isError'] == true || envelope is! Map) {
    checks.add(
      const ReadinessCheck(
        area,
        'pilot_answered',
        CheckOutcome.fail,
        'the read-only call was refused or did not answer',
      ),
    );
    return checks;
  }
  checks.add(
    check(
      'pilot_answered',
      envelope['status'] == 'completed',
      'the read-only call answered ${envelope['status']}',
    ),
  );
  checks.add(
    check(
      'pilot_provenance',
      envelope['operation'] == mcpPilotOperation &&
          envelope['workspace_id'] == workspaceId,
      'the answer is not for $mcpPilotOperation on the workspace asked about',
    ),
  );
  final allowed = <String>{
    if (pilotOp is Map) ...[
      for (final f in (pilotOp['output'] as List?) ?? const []) '$f',
      for (final f in (pilotOp['optional'] as List?) ?? const []) '$f',
    ],
  };
  final leaked = <String>{};
  void walk(Object? v) {
    if (v is Map) {
      for (final e in v.entries) {
        if (!allowed.contains('${e.key}')) leaked.add('${e.key}');
        walk(e.value);
      }
    } else if (v is List) {
      v.forEach(walk);
    }
  }

  walk(envelope['data']);
  checks.add(
    check(
      'pilot_output_minimized',
      leaked.isEmpty,
      '${leaked.length} unclassified field name(s) in the answer: ${(leaked.toList()..sort()).join(', ')}',
    ),
  );
  return checks;
}

String _opOf(Map<dynamic, dynamic> tool) {
  final name = '${tool['name']}';
  return name.startsWith('deskilo_') ? name.substring(8) : name;
}

Map<String, Object?>? _result(Object? response) {
  if (response is! Map) return null;
  final result = response['result'];
  return result is Map ? result.cast<String, Object?>() : null;
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1633 — controlled MCP activation, from a terminal, by the infrastructure
// operator (the Management API token is their authority; no workspace role
// and no app administrator can run any of this):
//
//   dart run tool/instance.dart mcp-inspect --ref R [--json]
//   dart run tool/instance.dart mcp-enable  --ref R --installation I --epoch N [--apply]
//   dart run tool/instance.dart mcp-pilot   --ref R --installation I --workspace W
//   dart run tool/instance.dart mcp-disable --ref R --installation I --reason pilot_failed|rollback|incident|operator_request [--apply]
//   dart run tool/instance.dart mcp-reset   --ref R --installation I --reason "<why>" [--apply]
//
//   Location (all optional; hosted defaults are candidates, confirmed by the
//   target before use): --auth-url <exact Auth URL> --endpoint <MCP endpoint>
//   --resource <canonical resource> --canonical-ref <canonical project>.
//   Secrets come from the environment only, never from arguments:
//   SUPABASE_ACCESS_TOKEN (required), DESKILO_TARGET_AUTH_ADMIN_KEY
//   (optional: reads Auth's OAuth clients and federation provider),
//   DESKILO_PILOT_TOKEN (mcp-pilot: the pilot user's own delegated token).
//
// The order is the point: inspect while OFF (exit 0 = ready for a controlled
// activation — nothing ran through MCP yet), enable exactly that
// installation and epoch on evidence measured NOW (the database refuses
// stale evidence), pilot one read-only call, and any pilot failure switches
// MCP off again with guards and audit kept. Rollback: disable first, then
// reset authority (the epoch moves; the endpoint must be redeployed with the
// new DESKILO_MCP_EPOCH; administrators are provisioned again with
// `db-admins grant … --apply`). Exit 0 = done or ready, 1 = refused or not
// ready, 2 = the command itself is wrong. Without --apply nothing is written.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/instance/management_api.dart';
import 'package:deskilo/core/instance/mcp_pilot.dart';
import 'package:deskilo/core/instance/mcp_readiness.dart';
import 'package:deskilo/core/instance/mcp_readiness_checks.dart';

import 'mcp_collect.dart';

const mcpCommands = {
  'mcp-inspect',
  'mcp-enable',
  'mcp-pilot',
  'mcp-disable',
  'mcp-reset',
};
const mcpDisableReasons = {
  'pilot_failed',
  'rollback',
  'incident',
  'operator_request',
};

final _ref = RegExp(r'^[a-z0-9]{20}$');
final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);
final _fingerprint = RegExp(r'^[0-9a-f]{32}$');

class _Usage implements Exception {
  const _Usage(this.message);
  final String message;
}

Map<String, String> _parse(List<String> argv, Set<String> allowed) {
  const flags = {'apply', 'json'};
  final options = <String, String>{};
  for (var i = 0; i < argv.length; i++) {
    final a = argv[i];
    if (!a.startsWith('--')) throw const _Usage('unexpected argument');
    final name = a.substring(2);
    if (!allowed.contains(name)) throw _Usage('unknown option --$name');
    if (options.containsKey(name)) throw _Usage('--$name given twice');
    if (flags.contains(name)) {
      options[name] = 'true';
    } else if (i + 1 < argv.length &&
        !argv[i + 1].startsWith('--') &&
        argv[i + 1].isNotEmpty) {
      options[name] = argv[++i];
    } else {
      throw _Usage('--$name needs a value');
    }
  }
  return options;
}

const _location = {'ref', 'auth-url', 'endpoint', 'resource', 'canonical-ref'};
const _allowed = {
  'mcp-inspect': {..._location, 'json'},
  'mcp-enable': {..._location, 'installation', 'epoch', 'apply'},
  'mcp-pilot': {..._location, 'installation', 'workspace'},
  'mcp-disable': {..._location, 'installation', 'reason', 'apply'},
  'mcp-reset': {..._location, 'installation', 'reason', 'apply'},
};

Uri? _url(String? value, String name) {
  if (value == null) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.hasScheme ||
      uri.host.isEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.userInfo.isNotEmpty ||
      value.endsWith('/')) {
    throw _Usage('--$name must be an exact URL without a trailing slash');
  }
  return uri;
}

/// The whole `mcp-*` family. [api] and [http] are injected by the tests.
Future<int> runMcp(
  List<String> argv, {
  Map<String, String>? environment,
  SupabaseManagement? api,
  McpTargetHttp? http,
  McpReleaseExpectation Function(Uri? resource)? release,
  IOSink? out,
}) async {
  final o = out ?? stdout;
  final env = environment ?? Platform.environment;
  final command = argv.firstOrNull ?? '';
  try {
    if (!mcpCommands.contains(command)) {
      throw const _Usage('unknown mcp command');
    }
    final opts = _parse(argv.skip(1).toList(), _allowed[command]!);
    final ref = opts['ref'];
    if (ref == null || !_ref.hasMatch(ref)) {
      throw const _Usage(
        '--ref must name exactly one project (20 lowercase letters and digits)',
      );
    }
    final canonicalRef = opts['canonical-ref'];
    if (canonicalRef != null &&
        (!_ref.hasMatch(canonicalRef) || canonicalRef == ref)) {
      throw const _Usage('--canonical-ref must name another project');
    }
    final installation = opts['installation'];
    if (command != 'mcp-inspect' &&
        (installation == null || !_uuid.hasMatch(installation))) {
      throw const _Usage(
        '--installation must be the target\'s installation id (from mcp-inspect)',
      );
    }
    final token = env['SUPABASE_ACCESS_TOKEN'] ?? '';
    if (token.isEmpty) throw const _Usage('SUPABASE_ACCESS_TOKEN is not set');
    final at = McpTargetLocation(
      ref: ref,
      authUrl: _url(opts['auth-url'], 'auth-url'),
      endpoint: _url(opts['endpoint'], 'endpoint'),
      canonicalRef: canonicalRef,
    );
    final resource = _url(opts['resource'], 'resource');
    final management = api ?? DioSupabaseManagement(token);
    final client = http ?? DioMcpTargetHttp();
    final expected =
        (release ?? (r) => loadMcpRelease('.', expectedResource: r))(resource);
    Future<McpReadinessReport> measure() async => evaluateMcpReadiness(
      await collectMcpEvidence(
        management,
        client,
        at,
        managementToken: token,
        authAdminKey: env['DESKILO_TARGET_AUTH_ADMIN_KEY'],
      ),
      expected,
    );
    final session = _Session(management, ref, installation ?? '', o);
    return switch (command) {
      'mcp-inspect' => _inspect(
        await measure(),
        o,
        json: opts['json'] == 'true',
      ),
      'mcp-enable' => await session.enable(
        await measure(),
        opts['epoch'],
        apply: opts['apply'] == 'true',
      ),
      'mcp-pilot' => await session.pilot(
        client,
        at,
        expected.catalogue,
        workspace: opts['workspace'],
        pilotToken: env['DESKILO_PILOT_TOKEN'],
      ),
      'mcp-disable' => await session.disable(
        opts['reason'],
        measure,
        apply: opts['apply'] == 'true',
      ),
      _ => await session.reset(
        opts['reason'],
        measure,
        apply: opts['apply'] == 'true',
      ),
    };
  } on _Usage catch (e) {
    // trace-exempt: a usage error is the CLI's answer; it never echoes values.
    o.writeln('usage: ${e.message}');
    return 2;
  } on ManagementApiException catch (e) {
    // trace-exempt: only the status is printed; API messages can carry details.
    o.writeln('refused: the Management API answered ${e.status}');
    return 1;
  }
}

String _mark(CheckOutcome o) => switch (o) {
  CheckOutcome.pass => 'ok     ',
  CheckOutcome.fail => 'FAIL   ',
  CheckOutcome.unknown => 'UNKNOWN',
};

/// The report as text (or its sanitized JSON), and the exit code.
int _inspect(McpReadinessReport report, IOSink o, {bool json = false}) {
  final ok =
      report.status == McpTargetStatus.readyForControlledActivation ||
      report.status == McpTargetStatus.activeVerified;
  if (json) {
    o.writeln(jsonEncode(report.toJson()));
    return ok ? 0 : 1;
  }
  final b = report.binding;
  o.writeln(
    'MCP readiness — ${b.ref}, installation ${b.installationId ?? 'unknown'}, '
    'epoch ${b.epoch ?? 'unknown'}, schema ${b.schemaVersion ?? 'unknown'}',
  );
  for (final area in ReadinessArea.values) {
    o.writeln('\n${area.name}: ${report.area(area).name}');
    for (final c in report.checks.where((c) => c.area == area)) {
      o.writeln(
        '  ${_mark(c.outcome)} ${c.code}${c.detail.isEmpty ? '' : ' — ${c.detail}'}',
      );
    }
  }
  o.writeln('\nstatus: ${report.status.name}');
  if (report.status == McpTargetStatus.readyForControlledActivation) {
    o.writeln(
      'Nothing ran through MCP while it was off: this is readiness for a controlled '
      'activation, not a business test. Next: mcp-enable --installation ${b.installationId} '
      '--epoch ${b.epoch} --apply, then mcp-pilot.',
    );
  } else if (report.status == McpTargetStatus.activeNotReady) {
    o.writeln('MCP is ON and not ready: mcp-disable --reason incident --apply');
  }
  return ok ? 0 : 1;
}

class _Session {
  _Session(this.api, this.ref, this.installation, this.o);
  final SupabaseManagement api;
  final String ref;
  final String installation;
  final IOSink o;

  bool _sameTarget(McpReadinessReport r) {
    if (r.binding.installationId == installation) return true;
    o.writeln(
      'refused: target_mismatch — $ref is installation '
      '${r.binding.installationId ?? 'unknown'}, not $installation',
    );
    return false;
  }

  Future<int> enable(
    McpReadinessReport r,
    String? epochText, {
    required bool apply,
  }) async {
    final epoch = int.tryParse(epochText ?? '');
    if (epoch == null || epoch < 1) {
      throw const _Usage('--epoch must be the inspected epoch');
    }
    if (!_sameTarget(r)) return 1;
    if (r.binding.epoch != epoch) {
      o.writeln(
        'refused: epoch_mismatch — $ref is at epoch ${r.binding.epoch}, not $epoch',
      );
      return 1;
    }
    if (r.status == McpTargetStatus.activeVerified) {
      o.writeln(
        'MCP is already on for $installation at epoch $epoch; nothing to do',
      );
      return 0;
    }
    if (r.status != McpTargetStatus.readyForControlledActivation) {
      o.writeln(
        'refused: not ready — ${[for (final c in r.blocking) c.code].join(', ')}',
      );
      return 1;
    }
    final fingerprint = r.binding.fingerprint ?? '';
    if (!_fingerprint.hasMatch(fingerprint)) {
      o.writeln('refused: the database answered no usable fingerprint');
      return 1;
    }
    if (!apply) {
      o.writeln(
        'dry run: would enable MCP on $ref (installation $installation, epoch $epoch, '
        'evidence $fingerprint). Nothing was written; add --apply.',
      );
      return 0;
    }
    return _write(
      "select public.operator_activate_mcp_runtime('$installation'::uuid, $epoch, '$fingerprint')::text as result",
      'MCP is on for $installation at epoch $epoch. Next: mcp-pilot --installation $installation '
          '--workspace <a workspace the pilot user consented to>',
    );
  }

  Future<int> pilot(
    McpTargetHttp http,
    McpTargetLocation at,
    Map<String, Object?> catalogue, {
    String? workspace,
    String? pilotToken,
  }) async {
    if (workspace == null || !_uuid.hasMatch(workspace)) {
      throw const _Usage(
        '--workspace must be the id of a workspace the pilot user consented to',
      );
    }
    if (pilotToken == null || pilotToken.isEmpty) {
      throw const _Usage(
        'DESKILO_PILOT_TOKEN is not set (the pilot user\'s own delegated token)',
      );
    }
    final state = await _state();
    if (state == null ||
        state['installation_id'] != installation ||
        state['enabled'] != true) {
      o.writeln(
        'refused: the pilot needs MCP ON for exactly installation $installation',
      );
      return 1;
    }
    final headers = {
      'Authorization': 'Bearer $pilotToken',
      'Accept': 'application/json, text/event-stream',
    };
    final list = await http.post(at.endpoint, {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'tools/list',
    }, headers: headers);
    final call = await http.post(at.endpoint, {
      'jsonrpc': '2.0',
      'id': 2,
      'method': 'tools/call',
      'params': {
        'name': 'deskilo_$mcpPilotOperation',
        'arguments': {'workspace_id': workspace},
      },
    }, headers: headers);
    final checks = evaluateMcpPilot(
      catalogue: catalogue,
      workspaceId: workspace,
      toolsList: list?.json,
      call: call?.json,
    );
    for (final c in checks) {
      o.writeln(
        '  ${_mark(c.outcome)} ${c.code}${c.detail.isEmpty ? '' : ' — ${c.detail}'}',
      );
    }
    if (checks.every((c) => c.passed)) {
      o.writeln(
        'pilot passed: one read-only call on $workspace, minimized, from installation $installation',
      );
      return 0;
    }
    o.writeln(
      'pilot failed: switching MCP off (guards, containment and audit stay)',
    );
    await _write(
      "select public.operator_disable_mcp_runtime('$installation'::uuid, 'pilot_failed')::text as result",
      'MCP is off.',
    );
    return 1;
  }

  Future<int> disable(
    String? reason,
    Future<McpReadinessReport> Function() measure, {
    required bool apply,
  }) async {
    if (reason == null || !mcpDisableReasons.contains(reason)) {
      throw _Usage('--reason must be one of ${mcpDisableReasons.join(', ')}');
    }
    final state = await _state();
    if (state == null || state['installation_id'] != installation) {
      o.writeln(
        'refused: target_mismatch — $ref is not installation $installation',
      );
      return 1;
    }
    if (!apply) {
      o.writeln(
        'dry run: would switch MCP off on $ref ($reason). Nothing was written; add --apply.',
      );
      return 0;
    }
    final code = await _write(
      "select public.operator_disable_mcp_runtime('$installation'::uuid, '$reason')::text as result",
      'MCP is off ($reason). Guards, containment and the audit are kept.',
    );
    if (code == 0) _native(await measure());
    return code;
  }

  Future<int> reset(
    String? reason,
    Future<McpReadinessReport> Function() measure, {
    required bool apply,
  }) async {
    if (reason == null || reason.trim().isEmpty || reason.length > 500) {
      throw const _Usage('--reason must say why (1 to 500 characters)');
    }
    final state = await _state();
    if (state == null || state['installation_id'] != installation) {
      o.writeln(
        'refused: target_mismatch — $ref is not installation $installation',
      );
      return 1;
    }
    if (state['enabled'] == true) {
      o.writeln(
        'refused: MCP is on. Switch it off first: mcp-disable --reason rollback --apply',
      );
      return 1;
    }
    if (!apply) {
      o.writeln(
        'dry run: would reset MCP authority on $ref: every connection, eligibility and '
        'administrator trust ends and the epoch moves past ${state['epoch']}. '
        'Nothing was written; add --apply.',
      );
      return 0;
    }
    final quoted = reason.replaceAll("'", "''");
    final code = await _write(
      "select public.operator_reset_mcp_authority('$installation'::uuid, '$quoted')::text as result",
      'authority reset. Redeploy the endpoint with the new DESKILO_MCP_EPOCH, then provision '
          'administrators again (dart run tool/instance.dart db-admins --ref $ref grant --email <address> --apply).',
    );
    if (code == 0) _native(await measure());
    return code;
  }

  /// Native access, re-checked after a rollback step: MCP being off must not
  /// have taken it away.
  void _native(McpReadinessReport r) {
    o.writeln(
      'native access after this step: ${r.area(ReadinessArea.nativeAccess).name}',
    );
    for (final c in r.checks.where(
      (c) => c.area == ReadinessArea.nativeAccess && !c.passed,
    )) {
      o.writeln('  ${_mark(c.outcome)} ${c.code}');
    }
  }

  Future<Map<String, Object?>?> _state() async {
    final rows = await api.query(ref, mcpReadinessSql);
    final r = rows.firstOrNull?['r'];
    final decoded = r is String ? jsonDecode(r) : r;
    return decoded is Map ? decoded.cast<String, Object?>() : null;
  }

  Future<int> _write(String sql, String done) async {
    try {
      final rows = await api.query(ref, sql);
      final result = rows.firstOrNull?['result'];
      final decoded = result is String ? jsonDecode(result) : result;
      final epoch = decoded is Map ? decoded['epoch'] : null;
      o.writeln(epoch == null ? done : '$done (epoch $epoch)');
      return 0;
    } on ManagementApiException catch (e) {
      // trace-exempt: the database's refusal names the rule that held.
      o.writeln('refused by the database: ${e.message}');
      return 1;
    }
  }
}

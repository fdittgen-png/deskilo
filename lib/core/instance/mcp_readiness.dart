// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1633 — whether ONE selected target may have its MCP runtime switched on,
// as six separate areas rather than one "ready" boolean:
//
//   native access          people sign in, confirm and recover their account
//   canonical federation   the identity authority, the Auth URL it really
//                          answers at, the upstream callback, the keys
//   database eligibility   administrators exist and are bound identities
//   workspace exposure     what owners chose to expose (counted, not judged)
//   user consent           what people consented to (counted, not judged)
//   MCP runtime            guard, contract, clients, endpoint, epoch
//
// Every check has three outcomes and only `pass` passes: a probe that could
// not be asked is `unknown`, and unknown blocks exactly like `fail`. MCP
// being off or undeployed never fails a native check. Nothing here reads a
// caller's verdict: the evaluator is given what was MEASURED on the target
// (tool/instance/mcp_collect.dart) and decides from that alone.
//
// A report is bound to the project ref, the installation id and the epoch it
// was measured on, and carries a digest of its own checks. A report for one
// target never certifies another, and a report whose status was edited no
// longer verifies (`verifyMcpReadinessReport`).
import 'dart:convert';

import 'package:crypto/crypto.dart';

enum ReadinessArea {
  nativeAccess,
  canonicalFederation,
  databaseEligibility,
  workspaceExposure,
  userConsent,
  mcpRuntime,
}

enum CheckOutcome { pass, fail, unknown }

/// One measured fact about the target, with the code an operator can act on.
class ReadinessCheck {
  const ReadinessCheck(this.area, this.code, this.outcome, [this.detail = '']);

  final ReadinessArea area;
  final String code;
  final CheckOutcome outcome;

  /// What was found. Never a secret, a user id or an e-mail address.
  final String detail;

  bool get passed => outcome == CheckOutcome.pass;

  Map<String, Object?> toJson() => {
    'area': area.name,
    'code': code,
    'outcome': outcome.name,
    if (detail.isNotEmpty) 'detail': detail,
  };
}

enum McpTargetStatus {
  /// MCP is off and every check passed. Not a claim that any business call
  /// succeeded: nothing ran through MCP while it was off.
  readyForControlledActivation,

  /// MCP is on and every check passed.
  activeVerified,

  /// MCP is off and something failed or could not be measured.
  notReady,

  /// MCP is ON and something failed or could not be measured: disable it.
  activeNotReady,
}

/// What a report is about. Two reports with different bindings are about
/// different things, whatever their checks say.
class McpTargetBinding {
  const McpTargetBinding({
    required this.ref,
    required this.installationId,
    required this.epoch,
    required this.schemaVersion,
    required this.fingerprint,
    required this.enabled,
  });

  final String ref;
  final String? installationId;
  final int? epoch;
  final int? schemaVersion;

  /// The database's fingerprint of the facts activation depends on.
  final String? fingerprint;
  final bool? enabled;

  Map<String, Object?> toJson() => {
    'ref': ref,
    'installation_id': installationId,
    'epoch': epoch,
    'schema_version': schemaVersion,
    'fingerprint': fingerprint,
    'enabled': enabled,
  };
}

class McpReadinessReport {
  McpReadinessReport(this.binding, this.checks);

  final McpTargetBinding binding;
  final List<ReadinessCheck> checks;

  /// The worst outcome of [area]'s checks; an area nothing measured is
  /// unknown, never a pass.
  CheckOutcome area(ReadinessArea area) {
    final mine = [
      for (final c in checks)
        if (c.area == area) c.outcome,
    ];
    if (mine.isEmpty || mine.contains(CheckOutcome.unknown)) {
      return mine.contains(CheckOutcome.fail)
          ? CheckOutcome.fail
          : CheckOutcome.unknown;
    }
    return mine.contains(CheckOutcome.fail)
        ? CheckOutcome.fail
        : CheckOutcome.pass;
  }

  /// Every check that is not a pass, in order: what stands in the way.
  List<ReadinessCheck> get blocking => [
    for (final c in checks)
      if (!c.passed) c,
  ];

  McpTargetStatus get status {
    final clean =
        binding.installationId != null &&
        binding.epoch != null &&
        binding.fingerprint != null &&
        binding.enabled != null &&
        ReadinessArea.values.every((a) => area(a) == CheckOutcome.pass);
    if (binding.enabled == true) {
      return clean
          ? McpTargetStatus.activeVerified
          : McpTargetStatus.activeNotReady;
    }
    return clean
        ? McpTargetStatus.readyForControlledActivation
        : McpTargetStatus.notReady;
  }

  Map<String, Object?> _body() => {
    'binding': binding.toJson(),
    'areas': {for (final a in ReadinessArea.values) a.name: area(a).name},
    'checks': [for (final c in checks) c.toJson()],
    'status': status.name,
  };

  /// The sanitized projection a support bundle or a CI artifact may keep.
  Map<String, Object?> toJson() {
    final body = _body();
    return {...body, 'digest': mcpReportDigest(body)};
  }
}

/// sha256 of [value] as canonical JSON (sorted keys).
String mcpReportDigest(Object? value) =>
    sha256.convert(utf8.encode(canonicalJson(value))).toString();

/// JSON with object keys sorted at every level, so two equal values always
/// encode, and hash, the same.
String canonicalJson(Object? value) {
  Object? sort(Object? v) => switch (v) {
    Map<dynamic, dynamic> m => {
      for (final k in (m.keys.map((k) => '$k').toList()..sort())) k: sort(m[k]),
    },
    List<dynamic> l => [for (final e in l) sort(e)],
    _ => v,
  };
  return jsonEncode(sort(value));
}

/// Why [report] may not be relied on for the target named, or null when it
/// is intact, about that exact target, and says it is ready.
///
/// A report is OUTPUT: the enable command never reads one (it measures
/// again), so this exists for whoever consumes an exported report.
String? verifyMcpReadinessReport(
  Map<String, Object?> report, {
  required String ref,
  required String installationId,
  required int epoch,
}) {
  final digest = report['digest'];
  final body = Map<String, Object?>.of(report)..remove('digest');
  if (digest is! String || mcpReportDigest(body) != digest) {
    return 'report_tampered';
  }
  final binding = body['binding'];
  if (binding is! Map ||
      binding['ref'] != ref ||
      binding['installation_id'] != installationId ||
      binding['epoch'] != epoch) {
    return 'report_for_other_target';
  }
  final checks = body['checks'];
  final areas = body['areas'];
  if (checks is! List || areas is! Map) return 'report_tampered';
  // The status is recomputed from the checks, never read from the report.
  final allPass =
      checks.isNotEmpty &&
      checks.every((c) => c is Map && c['outcome'] == CheckOutcome.pass.name) &&
      ReadinessArea.values.every(
        (a) => areas[a.name] == CheckOutcome.pass.name,
      );
  return allPass ? null : 'report_not_ready';
}

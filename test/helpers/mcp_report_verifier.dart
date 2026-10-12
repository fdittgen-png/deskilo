// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:deskilo/core/instance/mcp_readiness.dart';

String _digest(Object? value) =>
    sha256.convert(utf8.encode(canonicalJson(value))).toString();

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
  if (digest is! String || _digest(body) != digest) {
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

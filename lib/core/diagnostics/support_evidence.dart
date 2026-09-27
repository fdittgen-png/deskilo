// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

/// A bounded projection of #1634's release report, not a fresh health check.
/// Capability names, descriptions, prerequisites, references and private fields
/// never enter the support document. Unknown contracts/statuses fail closed.
class SupportEvidence {
  SupportEvidence._(this._counts);
  final Map<String, Map<String, int>> _counts;
  static const scopes = [
    'unit',
    'local_integration',
    'provider_sandbox',
    'named_runtime',
    'operator_pilot',
  ];
  static const standings = ['gated', 'recorded', 'stale', 'unverified'];
  static const maxSourceBytes = 1024 * 1024;

  static SupportEvidence? parse(String source) {
    if (source.length > maxSourceBytes ||
        utf8.encode(source).length > maxSourceBytes) {
      return null;
    }
    final Object? value;
    try {
      value = jsonDecode(source);
      // ignore: unused_catch_stack
    } catch (e, st) {
      // trace-exempt: malformed evidence is unavailable; source/errors are private.
      return null;
    }
    if (value is! Map || value['schema_version'] != 1) return null;
    final capabilities = value['capabilities'];
    if (capabilities is! List ||
        capabilities.isEmpty ||
        capabilities.length > 500) {
      return null;
    }
    final counts = {
      for (final scope in scopes) scope: {for (final s in standings) s: 0},
    };
    for (final item in capabilities) {
      if (item is! Map ||
          !const ['shipped', 'roadmap'].contains(item['status'])) {
        return null;
      }
      final evidence = item['scopes'];
      if (evidence is! Map ||
          evidence.keys.any((key) => !scopes.contains(key))) {
        return null;
      }
      for (final scope in scopes) {
        final standing = evidence[scope];
        if (!standings.contains(standing)) return null;
        counts[scope]![standing as String] = counts[scope]![standing]! + 1;
      }
    }
    return SupportEvidence._(counts);
  }

  Map<String, Object?> toJson() => {
    'contractVersion': 1,
    'source': 'releaseArtifact',
    'runtimeVerification': 'unavailable',
    'scopes': {
      for (final e in _counts.entries) e.key: Map<String, int>.of(e.value),
    },
  };
}

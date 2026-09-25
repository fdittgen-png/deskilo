// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1634 — what ships, what has been tested, at which scope, against
// which version: read from `docs/product/capabilities.json`, checked
// against the repository, and projected into a public page.
//
// Four dimensions stay separate and never fold into one green score:
// code present (`status`), a test gated at every commit (`gated`), a
// dated record against a component version (`recorded`), and a record
// the component has moved away from (`stale`). A reference supports a
// ceiling: a Dart test is a unit; a pgTAP file, a CI script or a CI row
// is a local integration against a stub or a replayed database; only a
// dated record under `docs/product/evidence/` reaches a provider
// sandbox, a named runtime or an operator pilot. A missing reference is
// a validation error, never an `unverified` cell; a skipped or failed
// record is `unverified`, never a pass. Pure dart:io, no live backend.
import 'dart:io';

import '../quality_rows/rows.dart' show parseManifest;

const manifestPath = 'docs/product/capabilities.json';
const pagePath = 'docs/product/CAPABILITIES.md';
const releasePath = 'docs/product/capabilities.release.json';
const evidenceDir = 'docs/product/evidence/';

/// Ascending: a record may claim no scope above its reference's ceiling.
const scopes = [
  'unit',
  'local_integration',
  'provider_sandbox',
  'named_runtime',
  'operator_pilot',
];
const _statuses = ['shipped', 'roadmap'];
const _outcomes = ['pass', 'fail', 'skipped'];
const _capabilityKeys = {
  'id', 'outcome', 'status', 'features', 'component', 'prerequisites',
  'limitations', 'provider', 'issues', 'evidence', //
};
const _evidenceKeys = {
  'scope', 'ref', 'sha', 'date', 'outcome', 'fingerprint', 'private', //
};

/// What a public projection must never carry: keys, tokens, addresses,
/// connection strings and links that are not this repository.
final _canaries = [
  RegExp(r'\b(sk|pk|rk)_(live|test)_\w+'),
  RegExp(r'\bwhsec_\w+'),
  RegExp(r'\beyJ[\w-]{16,}'),
  RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+'),
  RegExp(r'\bpostgres(ql)?://'),
  RegExp(r'https?://(?!github\.com/fdittgen-png/deskilo/)\S+'),
];

/// What the repository knows: the feature names an entry may cite and
/// the quality-report rows (name → job) a `ci:` reference may name.
class Context {
  Context({required this.root, required this.features, required this.ciJobs});

  factory Context.load(String root) {
    final source = File('$root/lib/features/workspace/domain/workspace_feature.dart')
        .readAsStringSync();
    final body = source.substring(source.indexOf('enum WorkspaceFeature {'));
    final rows = parseManifest(
        File('$root/.github/quality-manifest.psv').readAsStringSync());
    return Context(
      root: root,
      features: {
        for (final m in RegExp(r'^  ([a-z]\w*)\s*[,;(]', multiLine: true)
            .allMatches(body.substring(0, body.indexOf('\n}'))))
          m.group(1)!,
      },
      ciJobs: {for (final r in rows) r.name: r.job},
    );
  }

  final String root;
  final Set<String> features;
  final Map<String, String> ciJobs;

  bool exists(String path) =>
      File('$root/$path').existsSync() || Directory('$root/$path').existsSync();
  String read(String path) => File('$root/$path').readAsStringSync();
}

/// The highest scope [ref] can support; null when it is unknown or
/// absent. Every repository-local reference stops at `local_integration`:
/// a stub is not a provider and a replay is not a runtime.
String? ceiling(String ref, Context ctx) {
  if (ref.startsWith('ci:')) {
    final job = ctx.ciJobs[ref.substring(3)];
    return job == null ? null : scopes[job == 'database' ? 1 : 0];
  }
  if (!ctx.exists(ref)) return null;
  if (ref.startsWith('test/') && ref.endsWith('_test.dart')) return scopes[0];
  if (ref.startsWith('supabase/tests/database/') && ref.endsWith('.sql') ||
      ref.startsWith('scripts/') && ref.endsWith('.sh')) {
    return scopes[1];
  }
  if (ref.startsWith(evidenceDir) && ref.endsWith('.md')) {
    final m = RegExp(r'^scope: (\w+)$', multiLine: true).firstMatch(ctx.read(ref));
    return m != null && scopes.contains(m.group(1)) ? m.group(1) : null;
  }
  return null;
}

/// True for the scopes only a dated record can reach.
bool isRecorded(String scope) => scopes.indexOf(scope) >= 2;

/// [v] as a list of strings, or null when it is anything else.
List<String>? stringList(Object? v) =>
    v is List && v.every((e) => e is String) ? v.cast<String>() : null;

/// Every reason the manifest may not be published. Empty means valid.
List<String> validate(Map<String, Object?> manifest, Context ctx) {
  final problems = <String>[];
  if (manifest['schema_version'] != 1) problems.add('schema_version must be 1');
  if (manifest['version'] is! String) problems.add('version must be a string');
  final entries = manifest['capabilities'];
  if (entries is! List) return [...problems, 'capabilities must be a list'];
  final seen = <String>{};
  for (final raw in entries) {
    if (raw is! Map) {
      problems.add('capability must be an object');
      continue;
    }
    final c = raw.cast<String, Object?>();
    final id = c['id'] is String ? c['id'] as String : '?';
    void bad(String m) => problems.add('$id: $m');
    if (!RegExp(r'^[a-z][a-z0-9_.]*$').hasMatch(id)) bad('id is malformed');
    if (!seen.add(id)) bad('duplicate id');
    for (final k in c.keys.where((k) => !_capabilityKeys.contains(k))) {
      bad('unknown key `$k`');
    }
    for (final k in ['outcome', 'prerequisites', 'limitations']) {
      if (c[k] is! String) bad('$k must be a string');
    }
    if (!_statuses.contains(c['status'])) bad('status must be one of $_statuses');
    final features = stringList(c['features']);
    final component = stringList(c['component']);
    final evidence =
        c['evidence'] is List ? c['evidence'] as List : const <Object?>[];
    if (features == null) bad('features must be a list of strings');
    if (component == null) bad('component must be a list of strings');
    for (final f in features ?? const <String>[]) {
      if (!ctx.features.contains(f)) bad('unknown feature `$f`');
    }
    for (final p in component ?? const <String>[]) {
      if (!ctx.exists(p)) bad('component path `$p` does not exist');
    }
    if (c['status'] == 'shipped') {
      if ((component ?? const []).isEmpty) bad('shipped without a component');
      if (evidence.isEmpty) bad('shipped without evidence');
    } else if (c['status'] == 'roadmap') {
      if (evidence.isNotEmpty) bad('roadmap entries carry no evidence');
      if (c['issues'] is! List || (c['issues'] as List).isEmpty) {
        bad('roadmap entries name the issues that deliver them');
      }
    }
    final provider = c['provider'] as String?;
    for (final e in evidence) {
      if (e is! Map) {
        bad('evidence must be an object');
        continue;
      }
      final scope = e['scope'], ref = e['ref'];
      for (final k in e.keys.where((k) => !_evidenceKeys.contains(k))) {
        bad('unknown evidence key `$k`');
      }
      if (scope is! String || !scopes.contains(scope) || ref is! String) {
        bad('evidence needs a ref and a scope among $scopes');
        continue;
      }
      final cap = ceiling(ref, ctx);
      if (cap == null) {
        bad('evidence `$ref` does not exist or is not a recognised reference');
        continue;
      }
      if (scopes.indexOf(scope) > scopes.indexOf(cap)) {
        bad('`$ref` supports at most `$cap`, not `$scope`');
      }
      if (provider != null &&
          (ref.startsWith('ci:') ||
              !ctx.read(ref).toLowerCase().contains(provider.toLowerCase()))) {
        bad('`$ref` says nothing about `$provider` and cannot validate it');
      }
      if (!isRecorded(scope)) continue;
      if (!RegExp(r'^[0-9a-f]{7,40}$').hasMatch('${e['sha']}')) {
        bad('`$ref` needs the tested sha');
      }
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch('${e['date']}')) {
        bad('`$ref` needs a date');
      }
      if (!_outcomes.contains(e['outcome'])) {
        bad('`$ref` outcome must be one of $_outcomes');
      }
      if (!RegExp(r'^[0-9a-f]{12}$').hasMatch('${e['fingerprint']}')) {
        bad('`$ref` needs the component fingerprint it was taken against');
      }
      if (!ctx.read(ref).contains(id)) bad('`$ref` does not name $id');
    }
    for (final s in _publicStrings(c)) {
      for (final canary in _canaries) {
        if (canary.hasMatch(s)) bad('public text carries `${canary.stringMatch(s)}`');
      }
    }
  }
  return problems;
}

/// Every string a projection could print — the `private` block excluded.
Iterable<String> _publicStrings(Object? v) sync* {
  if (v is String) yield v;
  if (v is List) {
    for (final e in v) {
      yield* _publicStrings(e);
    }
  }
  if (v is Map) {
    for (final e in v.entries) {
      if (e.key != 'private') yield* _publicStrings(e.value);
    }
  }
}

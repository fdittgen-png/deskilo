// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3337 (of #3328) -- the physical removal check of a jurisdiction module.
//
// "Removable" is a claim until a check can say no. This one answers, for one
// package under `packages/`, what still needs it:
//
//   * another package that depends on it (a shared serializer or standard used
//     by a second country keeps the package in the build);
//   * source in the application that imports it, other than the composition
//     lists (`installed_*.dart`), which only register it and go with it;
//   * the runtime facts no source tree can show -- an enabled capability, a
//     pending submission, a correction route still needed -- which the caller
//     supplies as [RemovalFacts]. Without them the report says so: the static
//     half is never presented as the whole answer.
//
// Pure Dart over a directory tree; it reads no database and changes nothing.
import 'dart:io';

/// What no source scan can see, supplied by whoever asks (an operator query
/// against the instance). `null` means "not checked", which is not "none".
class RemovalFacts {
  const RemovalFacts({
    required this.enabledCapabilities,
    required this.pendingSubmissions,
    required this.neededCorrectionRoutes,
  });

  /// The enabled capabilities the module provides (`invoice_profile.fatturaPa`).
  final List<String> enabledCapabilities;

  /// Submissions through the module not yet settled.
  final int pendingSubmissions;

  /// Correction routes that still need the module.
  final List<String> neededCorrectionRoutes;

  factory RemovalFacts.fromJson(Map<String, Object?> json) => RemovalFacts(
    enabledCapabilities: [
      for (final c in (json['enabled_capabilities'] as List? ?? const []))
        '$c',
    ],
    pendingSubmissions: (json['pending_submissions'] as num? ?? 0).toInt(),
    neededCorrectionRoutes: [
      for (final c in (json['needed_correction_routes'] as List? ?? const []))
        '$c',
    ],
  );
}

/// Why a module cannot be removed.
enum BlockerKind {
  dependentPackage,
  dependentSource,
  enabledCapability,
  pendingSubmission,
  correctionRoute,
}

class Blocker {
  const Blocker(this.kind, this.subject);

  final BlockerKind kind;
  final String subject;

  @override
  String toString() => '${kind.name}: $subject';
}

class RemovalReport {
  RemovalReport(this.module, List<Blocker> blockers, {required this.runtime})
    : blockers = List.unmodifiable(blockers);

  final String module;

  /// Everything that still needs the module; empty = removable as far as the
  /// checked facts go.
  final List<Blocker> blockers;

  /// Whether the runtime facts were supplied. False = only the source half.
  final bool runtime;

  bool get removable => blockers.isEmpty;
}

final _importRe = RegExp(r'''^\s*(?:import|export)\s+['"]package:([a-z0-9_]+)/''');
final _depRe = RegExp(r'^  ([a-z0-9_]+):\s*$');

/// The packages (by name) under `<root>/packages` and the packages each
/// depends on by path.
Map<String, Set<String>> packageGraph(String root) {
  final graph = <String, Set<String>>{};
  final dir = Directory('$root/packages');
  if (!dir.existsSync()) return graph;
  for (final d in dir.listSync().whereType<Directory>()) {
    final pubspec = File('${d.path}/pubspec.yaml');
    if (!pubspec.existsSync()) continue;
    final name = d.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final deps = <String>{};
    var inDeps = false;
    for (final line in pubspec.readAsLinesSync()) {
      if (line.startsWith('dependencies:')) {
        inDeps = true;
        continue;
      }
      if (inDeps && line.isNotEmpty && !line.startsWith(' ')) inDeps = false;
      if (!inDeps) continue;
      final m = _depRe.firstMatch(line);
      if (m != null) deps.add(m.group(1)!);
    }
    graph[name] = deps;
  }
  return graph;
}

bool _isComposition(String path) =>
    RegExp(r'(^|/)installed_[a-z_]+\.dart$').hasMatch(path);

/// What still needs [module] in the tree at [root].
RemovalReport removalCheck(
  String root,
  String module, {
  RemovalFacts? facts,
}) {
  final blockers = <Blocker>[];
  final graph = packageGraph(root);
  for (final e in graph.entries) {
    if (e.key != module && e.value.contains(module)) {
      blockers.add(Blocker(BlockerKind.dependentPackage, e.key));
    }
  }
  final sources = <File>[
    for (final top in ['lib', 'test', 'tool'])
      if (Directory('$root/$top').existsSync())
        ...Directory('$root/$top')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart')),
  ];
  for (final f in sources) {
    final rel = f.path.substring(root.length + 1);
    if (_isComposition(rel) || rel.startsWith('test/')) continue;
    for (final line in f.readAsLinesSync()) {
      final m = _importRe.firstMatch(line);
      if (m != null && m.group(1) == module) {
        blockers.add(Blocker(BlockerKind.dependentSource, rel));
        break;
      }
    }
  }
  if (facts != null) {
    for (final c in facts.enabledCapabilities) {
      blockers.add(Blocker(BlockerKind.enabledCapability, c));
    }
    if (facts.pendingSubmissions > 0) {
      blockers.add(
        Blocker(BlockerKind.pendingSubmission, '${facts.pendingSubmissions}'),
      );
    }
    for (final r in facts.neededCorrectionRoutes) {
      blockers.add(Blocker(BlockerKind.correctionRoute, r));
    }
  }
  return RemovalReport(module, blockers, runtime: facts != null);
}

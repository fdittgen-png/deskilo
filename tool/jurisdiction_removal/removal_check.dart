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

/// What no source scan can see, read from `jurisdiction_removal_facts_v1` (0696)
/// for one space and handed over as its JSON. Ids, never counts: an operator
/// can open each one. `null` facts mean "not checked", which is not "none".
class RemovalFacts {
  const RemovalFacts({
    required this.enabledCapabilities,
    required this.unsettledTransmissions,
    required this.neededCorrectionRoutes,
    this.installation = false,
    this.workspaces = const [],
  });

  /// Whether this answers for the WHOLE installation (the operator's
  /// `jurisdiction_removal_facts_installation_v1`) or for one space under its
  /// manager (`jurisdiction_removal_facts_v1`). Removing a module is an
  /// installation decision: one space's clean answer proves nothing about
  /// the others, so only an installation answer can make a module removable.
  final bool installation;

  /// The spaces the blockers belong to, one entry per blocker in the same
  /// order (empty for a one-space answer).
  final List<String> workspaces;

  /// The enabled capabilities the module provides (`einvoice_channel.it_sdi`).
  final List<String> enabledCapabilities;

  /// The ids of transmissions through the module that could still complete.
  final List<String> unsettledTransmissions;

  /// The ids of the replacement invoices that still need the module to leave.
  final List<String> neededCorrectionRoutes;

  /// The function's own answer: lists of objects carrying `capability`,
  /// `transmission_id` and `invoice_id`; the installation answer groups them
  /// by space under `workspaces` and says `scope: installation`.
  factory RemovalFacts.fromJson(Map<String, Object?> json) {
    List<String> pick(Map<String, Object?> from, String list, String key) => [
      for (final e in (from[list] as List? ?? const []))
        if (e is Map && e[key] != null) '${e[key]}',
    ];
    if (json['scope'] == 'installation') {
      final caps = <String>[], tx = <String>[], routes = <String>[];
      final spaces = <String>[];
      for (final w in (json['workspaces'] as List? ?? const [])) {
        if (w is! Map<String, Object?>) continue;
        final id = '${w['workspace_id']}';
        for (final c in pick(w, 'enabled_capabilities', 'capability')) {
          caps.add(c);
          spaces.add(id);
        }
        for (final t in pick(w, 'unsettled_transmissions', 'transmission_id')) {
          tx.add(t);
          spaces.add(id);
        }
        for (final r in pick(w, 'needed_correction_routes', 'invoice_id')) {
          routes.add(r);
          spaces.add(id);
        }
      }
      return RemovalFacts(
        enabledCapabilities: caps,
        unsettledTransmissions: tx,
        neededCorrectionRoutes: routes,
        installation: true,
        workspaces: spaces,
      );
    }
    return RemovalFacts(
      enabledCapabilities: pick(json, 'enabled_capabilities', 'capability'),
      unsettledTransmissions: pick(
        json,
        'unsettled_transmissions',
        'transmission_id',
      ),
      neededCorrectionRoutes: pick(
        json,
        'needed_correction_routes',
        'invoice_id',
      ),
    );
  }
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
  const Blocker(this.kind, this.subject, {this.workspace = ''});

  final BlockerKind kind;
  final String subject;

  /// The space the work belongs to, when the facts name spaces.
  final String workspace;

  @override
  String toString() => workspace.isEmpty
      ? '${kind.name}: $subject'
      : '${kind.name}: $subject (space $workspace)';
}

class RemovalReport {
  RemovalReport(
    this.module,
    List<Blocker> blockers, {
    required this.runtime,
    this.installation = false,
  }) : blockers = List.unmodifiable(blockers);

  final String module;

  /// Everything that still needs the module; empty = removable as far as the
  /// checked facts go.
  final List<Blocker> blockers;

  /// Whether the runtime facts were supplied. False = only the source half.
  final bool runtime;

  /// Whether those facts cover the whole installation. A one-space answer is
  /// not a proof for the others.
  final bool installation;

  /// Nothing found that needs the module, in what was checked.
  bool get removable => blockers.isEmpty;

  /// Whether "removable" is a proof: the source half AND the runtime facts of
  /// the whole installation were checked.
  bool get proven => removable && runtime && installation;
}

final _importRe = RegExp(
  r'''^\s*(?:import|export)\s+['"]package:([a-z0-9_]+)/''',
);
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
RemovalReport removalCheck(String root, String module, {RemovalFacts? facts}) {
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
    String space(int i) =>
        i < facts.workspaces.length ? facts.workspaces[i] : '';
    var at = 0;
    for (final c in facts.enabledCapabilities) {
      blockers.add(
        Blocker(BlockerKind.enabledCapability, c, workspace: space(at++)),
      );
    }
    for (final t in facts.unsettledTransmissions) {
      blockers.add(
        Blocker(BlockerKind.pendingSubmission, t, workspace: space(at++)),
      );
    }
    for (final r in facts.neededCorrectionRoutes) {
      blockers.add(
        Blocker(BlockerKind.correctionRoute, r, workspace: space(at++)),
      );
    }
  }
  return RemovalReport(
    module,
    blockers,
    runtime: facts != null,
    installation: facts?.installation ?? false,
  );
}

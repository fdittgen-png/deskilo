// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1327 — one search over the three levels of the process registry.
//
// An owner does not know which level the thing they want lives at:
// "invoice" is a process description, a subprocess and five feature
// names. So the query is matched against every level's localised name
// and description in the reader's language, and each hit carries the
// path above it, so a feature is never shown without the process and
// subprocess it belongs to.
//
// There are no aliases: the registry has none (#1327 audit), and a
// hand-kept synonym list in one language would be wrong in four.
import '../../../l10n/app_localizations.dart';
import '../domain/workspace_feature.dart';
import '../domain/workspace_process.dart';
import 'feature_copy.dart';
import 'feature_names.dart';
import 'process_names.dart';

enum ProcessHitKind { process, subprocess, feature }

class ProcessSearchHit {
  const ProcessSearchHit({
    required this.kind,
    required this.processKey,
    required this.title,
    required this.path,
    this.subprocessKey,
    this.feature,
  });

  final ProcessHitKind kind;
  final String processKey;
  final String? subprocessKey;
  final WorkspaceFeature? feature;

  /// The matched item's own name.
  final String title;

  /// The names above it, outermost first — empty for a process.
  final List<String> path;

  /// A stable identity, for keys.
  String get id => switch (kind) {
    ProcessHitKind.process => processKey,
    ProcessHitKind.subprocess => subprocessKey!,
    ProcessHitKind.feature => feature!.name,
  };
}

/// Every item whose name or description contains [query], in registry
/// order, each level before the levels beneath it. An empty query finds
/// nothing: the overview shows its cards instead.
List<ProcessSearchHit> searchProcesses(
  AppLocalizations? l10n,
  String query, {
  List<WorkspaceProcess> processes = workspaceProcesses,
}) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];
  bool found(String title, String description) =>
      title.toLowerCase().contains(needle) ||
      description.toLowerCase().contains(needle);

  final hits = <ProcessSearchHit>[];
  for (final process in processes) {
    final processCopyText = processCopy(l10n, process.key);
    if (found(processCopyText.title, processCopyText.description)) {
      hits.add(
        ProcessSearchHit(
          kind: ProcessHitKind.process,
          processKey: process.key,
          title: processCopyText.title,
          path: const [],
        ),
      );
    }
    for (final subprocess in process.subprocesses) {
      final subCopy = processCopy(l10n, subprocess.key);
      if (found(subCopy.title, subCopy.description)) {
        hits.add(
          ProcessSearchHit(
            kind: ProcessHitKind.subprocess,
            processKey: process.key,
            subprocessKey: subprocess.key,
            title: subCopy.title,
            path: [processCopyText.title],
          ),
        );
      }
      for (final feature in subprocess.capabilities) {
        final name = featureName(l10n, feature);
        if (found(name, featureDescription(l10n, feature))) {
          hits.add(
            ProcessSearchHit(
              kind: ProcessHitKind.feature,
              processKey: process.key,
              subprocessKey: subprocess.key,
              feature: feature,
              title: name,
              path: [processCopyText.title, subCopy.title],
            ),
          );
        }
      }
    }
  }
  return hits;
}

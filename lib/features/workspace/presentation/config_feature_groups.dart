// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2862 — the configuration PDF lists the features that are on one line
// per process, in catalogue order, instead of a page of single names.
import '../../../l10n/app_localizations.dart';
import '../domain/workspace_config_report.dart';
import '../domain/workspace_feature.dart';
import '../domain/workspace_process.dart';
import 'feature_names.dart';
import 'process_names.dart';

/// The features in [on], grouped by process; a process with none of them
/// on is left out.
List<ConfigFeatureGroup> configFeatureGroups(
  AppLocalizations l10n,
  Set<WorkspaceFeature> on,
) => [
  for (final process in workspaceProcesses)
    if ([
          for (final sub in process.subprocesses)
            for (final f in sub.capabilities)
              if (on.contains(f)) featureName(l10n, f),
        ]
        case final names when names.isNotEmpty)
      (process: processLabel(l10n, process.key), features: names),
];

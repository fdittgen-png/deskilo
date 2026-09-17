// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_process.dart';
import '../feature_copy.dart';
import '../feature_names.dart';
import '../process_names.dart';

/// Read-only hierarchy. Saved choices and effective dependencies are distinct.
class ProcessDetails extends StatelessWidget {
  const ProcessDetails({super.key, required this.raw,
    this.processes = workspaceProcesses});
  final Set<WorkspaceFeature> raw;
  final List<WorkspaceProcess> processes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n?.processDetails ?? 'Processes and dependencies')),
      body: ListView(children: [
        for (final process in processes)
          ExpansionTile(
            key: ValueKey('process-${process.key}'),
            title: Text(processLabel(l10n, process.key)),
            subtitle: Text(processCopy(l10n, process.key).description),
            children: [
              for (final subprocess in process.subprocesses)
                ExpansionTile(
                  title: Text(processLabel(l10n, subprocess.key)),
                  subtitle: Text('${processCopy(l10n, subprocess.key).description}\n${
                      subprocess.capabilities.every(effectiveFeatures(raw).contains)
                          ? l10n?.processAvailable ?? 'Available'
                          : l10n?.processUnavailable ?? 'Unavailable'}'),
                  children: [
                    for (final feature in subprocess.capabilities)
                      ListTile(
                        title: Text(featureName(l10n, feature)),
                        subtitle: Text(_state(l10n, feature)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(builder: (_) => CapabilityDetails(
                            feature: feature, raw: raw, processes: processes))),
                      ),
                  ],
                ),
            ],
          ),
      ]),
    );
  }

  String _state(AppLocalizations? l10n, WorkspaceFeature feature) {
    if (!raw.contains(feature)) return l10n?.processStoredOff ?? 'Saved off';
    final missing = requirementChain(feature).where((f) => !raw.contains(f));
    if (missing.isEmpty) return l10n?.processStoredOn ?? 'Saved on';
    final names = missing.map((f) => featureName(l10n, f)).join(', ');
    return l10n?.processMissingPrerequisites(names) ?? 'Held back by $names';
  }
}

class CapabilityDetails extends StatelessWidget {
  const CapabilityDetails({super.key, required this.feature, required this.raw,
    this.processes = workspaceProcesses});
  final WorkspaceFeature feature;
  final Set<WorkspaceFeature> raw;
  final List<WorkspaceProcess> processes;

  String _home(AppLocalizations? l10n, WorkspaceFeature capability) => [
    for (final process in processes)
      for (final subprocess in process.subprocesses)
        if (subprocess.capabilities.contains(capability))
          '${processLabel(l10n, process.key)} → ${processLabel(l10n, subprocess.key)}',
  ].join(', ');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final effective = effectiveFeatures(raw);
    final parents = requirementChain(feature);
    final missing = parents.where((f) => !raw.contains(f));
    final missingNames = missing.map((f) => featureName(l10n, f)).join(', ');
    return Scaffold(
      appBar: AppBar(title: Text(featureName(l10n, feature))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(_home(l10n, feature)),
        Text(featureDescription(l10n, feature)),
        Text(raw.contains(feature)
            ? l10n?.processStoredOn ?? 'Saved on'
            : l10n?.processStoredOff ?? 'Saved off'),
        if (raw.contains(feature) && missing.isNotEmpty)
          Text(l10n?.processMissingPrerequisites(missingNames) ?? 'Held back by $missingNames'),
        for (final parent in parents)
          ListTile(
            key: ValueKey('requires-${parent.dbKey}'),
            leading: Icon(effective.contains(parent) ? Icons.check : Icons.block,
              semanticLabel: effective.contains(parent)
                  ? l10n?.processAvailable ?? 'Available'
                  : l10n?.processUnavailable ?? 'Unavailable'),
            title: Text(l10n?.featureRequires(featureName(l10n, parent)) ??
                'Requires ${featureName(l10n, parent)}'),
            subtitle: Text(_home(l10n, parent)),
          ),
        Text(l10n?.processUsedBy ?? 'Used by'),
        for (final child in dependentFeatures(feature))
          ListTile(
            leading: Icon(effective.contains(child) ? Icons.check : Icons.block,
              semanticLabel: effective.contains(child)
                  ? l10n?.processAvailable ?? 'Available'
                  : l10n?.processUnavailable ?? 'Unavailable'),
            title: Text(featureName(l10n, child)),
            subtitle: Text('${_home(l10n, child)}\n${
                raw.contains(child) ? l10n?.processStoredOn ?? 'Saved on'
                    : l10n?.processStoredOff ?? 'Saved off'}'),
          ),
        if (feature == WorkspaceFeature.adminInvoicing)
          Text(l10n?.processAdminGrant ??
              'When effective, this capability permits admins to issue invoices.'),
        ExpansionTile(
          title: Text(l10n?.processTechnicalKey ?? 'Technical key'),
          children: [SelectableText(feature.dbKey)],
        ),
      ]),
    );
  }
}

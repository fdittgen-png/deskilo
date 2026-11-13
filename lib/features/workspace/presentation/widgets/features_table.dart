// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3619 (desk M6) — the features at the desk: one records table (#3606) of
// every feature, what it does, whether it is on and what it depends on, with
// the table's filter and On, Off and Changed as chips. A switch is the same
// write as on the list (switchWorkspaceFeature): a child brings its parent,
// a feature the country does not offer is never switched on.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/kit/records_table.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace_feature.dart';
import '../feature_copy.dart';
import '../feature_names.dart';

/// The features as a table; [onChanged] writes a switch.
class FeaturesTable extends StatelessWidget {
  const FeaturesTable({
    super.key,
    required this.raw,
    required this.country,
    required this.onChanged,
  });

  /// The stored set (a child's saved choice survives its parent's off).
  final Set<WorkspaceFeature> raw;
  final String country;
  final void Function(WorkspaceFeature feature, {required bool value})
  onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final effective = effectiveFeatures(raw);
    return RecordsTable<FeatureManifestEntry>(
      tableId: 'features',
      rows: featureManifest.values.toList(),
      keyOf: (e) => e.feature.name,
      searchText: (e) =>
          '${featureName(l, e.feature)} ${featureDescription(l, e.feature)}',
      onOpen: (_) {},
      empty: Center(child: Text(l.featuresTitle)),
      initialQuery: const RecordsQuery(sortColumn: 'feature'),
      chips: [
        RecordChip(
          id: 'on',
          label: l.processFeatureOn,
          keeps: (e) => effective.contains(e.feature),
        ),
        RecordChip(
          id: 'off',
          label: l.processFeatureOff,
          keeps: (e) => !effective.contains(e.feature),
        ),
        RecordChip(
          id: 'changed',
          label: l.featuresFilterChanged,
          keeps: (e) => raw.contains(e.feature) != e.defaultOn,
        ),
      ],
      columns: [
        RecordColumn(
          id: 'feature',
          label: l.featuresColFeature,
          flex: 3,
          hideable: false,
          sortKey: (e) => featureName(l, e.feature).toLowerCase(),
          cell: (_, e) => Text(featureName(l, e.feature)),
        ),
        RecordColumn(
          id: 'does',
          label: l.featuresColDoes,
          flex: 6,
          cell: (_, e) => Text(featureDescription(l, e.feature)),
        ),
        RecordColumn(
          id: 'state',
          label: l.featuresColState,
          flex: 2,
          sortKey: (e) => raw.contains(e.feature) ? 0 : 1,
          cell: (_, e) => Text(
            raw.contains(e.feature) ? l.processFeatureOn : l.processFeatureOff,
          ),
        ),
        RecordColumn(
          id: 'depends',
          label: l.featuresColDepends,
          flex: 3,
          cell: (_, e) => Text(switch (e.requires) {
            final parent? => featureName(l, parent),
            null => '',
          }),
        ),
      ],
      // The switch is the row's action: the table's keyboard reaches it.
      rowActions: (e) => [_action(l, e)],
      cardBuilder: (context, e) => ListTile(
        title: Text(featureName(l, e.feature)),
        subtitle: Text(featureDescription(l, e.feature)),
        trailing: Text(
          raw.contains(e.feature) ? l.processFeatureOn : l.processFeatureOff,
        ),
      ),
    );
  }

  /// Switch on or off; a feature the country does not offer is never
  /// switched on (a stored on can be switched off).
  RecordAction<FeatureManifestEntry> _action(
    AppLocalizations l,
    FeatureManifestEntry e,
  ) {
    final on = raw.contains(e.feature);
    final available = featureAvailableIn(e.availableIn, country);
    return RecordAction(
      id: 'switch',
      label: on ? l.processSwitchOff : l.processSwitchOn,
      icon: on ? Icons.toggle_on_outlined : Icons.toggle_off_outlined,
      unavailable: available || on
          ? null
          : featureAvailableNote(l, e.availableIn!),
      onRun: (e) => onChanged(e.feature, value: !on),
    );
  }
}

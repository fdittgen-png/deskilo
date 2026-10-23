// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ADR 0047 §3 — the server's copy of the levels and the presets.
// An assistant previews and applies levels through the database, so the
// database reads the same table the app does: `tool/build_setup_steps.dart`
// prints this statement, and the migration that defines
// `setup_level_catalogue()` carries it unchanged
// (`test/lint/setup_levels_contract_test.dart`).
import 'dart:convert';

import 'setup_levels.dart';
import 'workspace_feature.dart';

/// The levels and presets as JSON: processes in guide order, levels lowest
/// first, each level's features in registry order by their stored key.
Map<String, Object?> _setupLevelCatalogue() => {
  'processes': [
    for (final process in SetupProcess.values)
      {
        'process': process.name,
        'levels': [
          for (final level in setupLevels[process]!)
            {
              'level': level.id,
              'features': [
                for (final f in WorkspaceFeature.values)
                  if (level.features.contains(f)) f.dbKey,
              ],
              'needs': [
                for (final MapEntry(key: needed, value: minimum)
                    in level.needs.entries)
                  {'process': needed.name, 'level': minimum},
              ],
            },
        ],
      },
  ],
  'presets': [
    for (final preset in SetupPreset.values)
      {
        'preset': preset.name,
        'levels': [
          for (final process in SetupProcess.values)
            if (setupPresets[preset]![process] case final level?)
              {'process': process.name, 'level': level},
        ],
      },
  ],
};

/// The statement a migration carries verbatim.
String setupLevelCatalogueSql() =>
    '''
create or replace function public.setup_level_catalogue()
returns jsonb language sql immutable set search_path = public as $_fn
  select $_json${jsonEncode(_setupLevelCatalogue())}$_json::jsonb;
$_fn;
revoke execute on function public.setup_level_catalogue() from public, anon, authenticated;''';

// The SQL dollar-quotes, kept out of interpolation.
const _fn = r'$fn$';
const _json = r'$json$';

// SPDX-License-Identifier: 0BSD
import 'workspace_feature.dart';

/// #1333 — the feature registry as the database reads it.
///
/// The client decides whether a feature is on in two steps: a stored JSON
/// boolean over the registry default, then every `requires` parent on
/// (`resolveEnabledFeatures` → `effectiveFeatures`). Server gates used to
/// read the one flag in front of them, each with its own idea of the
/// default, so a child stored `true` under a parent switched off passed a
/// gate the app showed as off (#1332).
///
/// The SQL `public.feature_registry()` carries, per key, the parent, the
/// default and whether the feature is core — generated HERE from
/// [featureManifest], never typed by hand. `feature_registry_sql_test`
/// requires the latest migration defining the function to contain exactly
/// this text, so adding or re-parenting a feature without a migration that
/// regenerates it fails the build and names the feature.
String featureRegistryJson() {
  final lines = <String>[];
  for (final entry in featureManifest.values) {
    final parent = entry.requires == null ? 'null' : '"${entry.requires!.dbKey}"';
    lines.add('    "${entry.feature.dbKey}": {"parent": $parent, '
        '"default": ${entry.defaultOn}, '
        '"core": ${entry.tier == FeatureTier.core}}');
  }
  return '{\n${lines.join(',\n')}\n  }';
}

/// The whole `create or replace function` statement for a migration.
///
/// `immutable`: the registry is compiled into the schema; it changes only
/// when a migration replaces the function.
String featureRegistrySql() => '''
create or replace function public.feature_registry()
returns jsonb
language sql
immutable
set search_path = public
as \$registry\$
  select '${featureRegistryJson()}'::jsonb
\$registry\$;''';

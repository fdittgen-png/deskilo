// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1655 — nothing a template could carry stays without a disposition.
//
// `templateFieldRegistry()` says, per field, whether it travels, what an
// absent value means and what the target must supply. This reads every
// source a field can come from and fails when one has a member the
// registry does not answer for:
//
//   * every column of `workspaces` (the existing migration parser);
//   * every `workspace_keys` entry and every table of a deployable entity,
//     read from the SQL as a union over all migrations — an anchored patch
//     that retires a key leaves it needing a disposition, not exempt;
//   * every column each table's export block emits, nested keys included;
//   * every JSON key the compiled domain classes write — booking rules,
//     billing, dunning, branding, subscription levels, number sequences;
//   * every feature, every permission on every configurable role, every
//     overridable lexicon term.
//
// The registry is also held to itself: unique canonical ids, a reason on
// everything that never travels, a binding on every reference, enum
// values equal to the Dart enums the client writes.
import 'dart:io';

import 'package:deskilo/core/l10n/lexicon.dart';
import 'package:deskilo/core/time/work_hours.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/domain/number_sequence.dart';
import 'package:deskilo/features/money/domain/subscription_levels.dart';
import 'package:deskilo/features/money/domain/workspace_status.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:deskilo/features/workspace/domain/booking_policies.dart';
import 'package:deskilo/features/workspace/domain/new_member_defaults.dart';
import 'package:deskilo/features/workspace/domain/template_field_registry.dart';
import 'package:deskilo/features/workspace/domain/workspace_branding.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/domain/workspace_process.dart';
import 'package:flutter_test/flutter_test.dart';

import 'configuration_classification_test.dart'
    show deployableEntityKeys, workspaceColumns;

final _registry = templateFieldRegistry();
final _ids = {for (final s in _registry) s.id};

/// A field is covered by its own record or by records beneath it
/// (`workspace.booking_rules` by `workspace.booking_rules.granularity`).
bool _covered(String id) =>
    _ids.contains(id) || _ids.any((i) => i.startsWith('$id.'));

/// A table column is covered by a record under that table ending in it,
/// at any depth (`labels.[locale].label` covers the nested `label`).
bool _columnCovered(String table, String column) {
  final prefix = table == 'floor_plan' ? 'floor_plan[]' : 'tables.$table[]';
  return _ids.any((i) => i.startsWith(prefix) && i.endsWith('.$column'));
}

/// Every migration, with the doubled quotes of plpgsql string literals
/// folded: 0186 builds the accessories export as `'' || E'\n' ||` text.
Iterable<String> _sql() => (Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path)))
    .map((f) => f.readAsStringSync().replaceAll("''", "'"));

/// Every value ever listed under `'<field>', '[…]'::jsonb` in an entity
/// object, over all migrations.
Set<String> _entityArrays(String field) {
  final re = RegExp("'$field',\\s*'\\[([^\\]]*)\\]'::jsonb");
  return {
    for (final sql in _sql())
      for (final m in re.allMatches(sql))
        for (final k in RegExp(r'"([a-z_]+)"').allMatches(m.group(1)!))
          k.group(1)!,
  };
}

/// The keys a table's export block emits: the inline
/// `coalesce((select jsonb_agg(jsonb_build_object(` idiom, or a helper
/// named `…_export(` whose body is read the same way. Nested
/// `jsonb_build_object` keys count.
Set<String> _exportColumns(String table) {
  final keys = <String>{};
  // The block runs to `from public.<table>` without crossing another
  // aggregate: a patch that quotes a block as its ANCHOR (0186, 0250) is
  // followed by some other table's text, and must not count.
  final inline = RegExp(
      "'$table',\\s*coalesce\\(\\(select jsonb_agg\\(jsonb_build_object\\("
      "((?:(?!jsonb_agg\\().)*?)from public\\.$table\\b",
      dotAll: true);
  final helper = RegExp("'$table',\\s*public\\.([a-z_]+_export)\\(");
  for (final sql in _sql()) {
    for (final m in inline.allMatches(sql)) {
      keys.addAll(_keysUntilFrom(m.group(1)!, all: true));
    }
    for (final m in helper.allMatches(sql)) {
      final def = RegExp(
          'function public\\.${m.group(1)}\\(.*?as\\s+\\\$([a-z]*)\\\$(.*?)\\\$\\1\\\$',
          dotAll: true);
      for (final s in _sql()) {
        final body = def.firstMatch(s);
        if (body != null) keys.addAll(_keysUntilFrom(body.group(2)!, all: true));
      }
    }
  }
  return keys;
}

Set<String> _keysUntilFrom(String text, {bool all = false}) {
  final end = all ? text.length : text.indexOf('from public.');
  return {
    for (final m in RegExp(r"'([a-z_]+)',\s").allMatches(text.substring(0, end < 0 ? text.length : end)))
      m.group(1)!,
  };
}

void main() {
  test('the registry is canonical and complete about itself', () {
    expect(_ids.length, _registry.length, reason: 'duplicate ids');
    expect([for (final s in _registry) s.id], [..._ids]..sort(),
        reason: 'ids are emitted in canonical (sorted) order');
    for (final s in _registry) {
      final where = s.id;
      if (s.portability == TemplatePortability.never ||
          s.portability == TemplatePortability.unsupported) {
        expect(s.reason, isNotNull, reason: '$where: never/unsupported needs a reason');
      }
      if (s.portability == TemplatePortability.reference) {
        expect(s.bindings, isNotEmpty, reason: '$where: a reference names what it resolves');
      }
      expect(entityProcesses.containsKey(s.entity), isTrue, reason: '$where: entity ${s.entity} has no process');
      expect(workspaceProcesses.any((p) => p.key == templateFieldProcess(s)), isTrue,
          reason: '$where: process ${templateFieldProcess(s)} does not exist');
      for (final d in s.dependsOn) {
        expect(_ids.contains(d) || entityProcesses.containsKey(d), isTrue,
            reason: '$where: depends on unknown $d');
      }
      if (s.id.startsWith('tables.') || s.id.startsWith('floor_plan[]')) {
        expect(s.naturalKey, isNotNull, reason: '$where: a row field names its natural key');
      }
    }
  });

  test('every workspaces column has a disposition', () {
    // The column and its export key differ for one setting.
    const alias = {'subscription_vat_rate_id': 'subscription_vat_rate'};
    final missing = [
      for (final c in workspaceColumns())
        if (!_covered('workspace.${alias[c] ?? c}')) c,
    ]..sort();
    expect(missing, isEmpty, reason: 'workspaces columns without a field record:\n  ${missing.join('\n  ')}');
  });

  test('every deployable entity, workspace key and table has records', () {
    final entities = deployableEntityKeys();
    final problems = <String>[
      for (final e in entities)
        if (!_registry.any((s) => s.entity == e)) 'entity $e has no field record',
      for (final e in entities)
        if (!entityProcesses.containsKey(e)) 'entity $e has no process',
      for (final k in _entityArrays('workspace_keys'))
        if (!_covered('workspace.$k')) 'workspace key $k',
      for (final t in _entityArrays('tables'))
        if (!_ids.any((i) => i.startsWith(t == 'floor_plan' ? 'floor_plan[]' : 'tables.$t[]')))
          'table $t',
    ];
    expect(problems, isEmpty, reason: problems.join('\n'));
    expect(entities.length, greaterThanOrEqualTo(24), reason: 'the entity parse shrank');
  });

  test('every exported table column, nested keys included, has a record', () {
    final problems = <String>[];
    var seen = 0;
    for (final t in _entityArrays('tables')) {
      if (t == 'floor_plan') continue;
      final columns = _exportColumns(t);
      expect(columns, isNotEmpty, reason: '$t: no export block found — the parser lost the table');
      seen += columns.length;
      for (final c in columns) {
        if (!_columnCovered(t, c)) problems.add('$t.$c');
      }
    }
    expect(problems, isEmpty, reason: 'exported columns without a field record:\n  ${problems.join('\n  ')}');
    expect(seen, greaterThanOrEqualTo(80), reason: 'the column parse found fewer keys than the tables emit');
  });

  test('every JSON key the client writes has a record', () {
    final keys = <String, Set<String>>{
      'booking_rules': {
        BookingRulesKeys.granularity, 'open_weekdays', 'max_series_days',
        BookingPolicies.allowPastBookingsKey, BookingPolicies.adminCheckOutKey,
        BookingPolicies.gridWithinHoursKey, BookingPolicies.outsideHoursModeKey,
        BookingPolicies.simultaneousReservationsKey, BookingPolicies.legendProfileKey,
        BookingPolicies.advanceHorizonDaysKey, BookingPolicies.minDurationMinutesKey,
        BookingPolicies.maxDurationMinutesKey, WorkHours.keyStart, WorkHours.keyBoundary,
        WorkHours.keyEnd, WorkHours.keyHalfDayHours, WorkHours.keyFullDayHours,
      },
      'billing_rules': {
        ...const BillingRules().toJson().keys,
        for (final k in const NewMemberDefaults().toValue().keys) '$newMemberDefaultsKey.$k',
        for (final k in const RepartitionRule().toJson().keys) 'repartition.$k',
      },
      'dunning_rules': const DunningRules().toJson().keys.toSet(),
      'branding': {BrandingKeys.seedColor, BrandingKeys.officePalette, BrandingKeys.seatPalette},
      'subscription_levels': SubscriptionLevels.fromDb(const <String, dynamic>{}).toDb().keys.toSet(),
      'feature_flags': {for (final f in WorkspaceFeature.values) f.dbKey},
      'lexicon': {for (final t in lexiconAllowList.keys) '{locale}.$t'},
      'role_permissions': {'co_owner', 'admin', 'member'},
    };
    final missing = [
      for (final e in keys.entries)
        for (final k in e.value)
          if (!_covered('workspace.${e.key}.$k')) '${e.key}.$k',
      for (final k in [NumberSequence.keyJournal, NumberSequence.keyPrefix, NumberSequence.keySuffix,
        NumberSequence.keyDatePart, NumberSequence.keyDigits, NumberSequence.keyReset,
        NumberSequence.keyNextValue, NumberSequence.keyPeriodKey])
        if (!_ids.contains('tables.number_sequences[].$k')) 'number_sequences.$k',
    ]..sort();
    expect(missing, isEmpty, reason: 'JSON keys without a field record:\n  ${missing.join('\n  ')}');
  });

  test('the literals the generator needs equal the compiled sources, both ways', () {
    TemplateFieldSpec spec(String id) => _registry.firstWhere((s) => s.id == id);
    // A permission is covered when every configurable role's list names it,
    // and a role list names nothing that is not a permission.
    final wires = [for (final p in WorkspacePermission.values) p.wireName];
    for (final r in ['co_owner', 'admin', 'member']) {
      expect(spec('workspace.role_permissions.$r').values, wires,
          reason: '$r: the permission list is WorkspacePermission, in order');
    }
    expect(spec('tables.workspace_roles[].permissions').values, wires);
    final terms = {
      for (final s in _registry)
        if (s.id.startsWith('workspace.lexicon.{locale}.')) s.id.split('.').last,
    };
    expect(terms, lexiconAllowList.keys.toSet(),
        reason: 'the lexicon terms are the allow-list, no more and no less');
    expect(spec('workspace.booking_rules.granularity').values,
        [for (final g in BookingGranularity.values) g.wireName]);
    expect(spec('workspace.booking_rules.outside_hours_mode').values,
        [for (final m in OutsideHoursMode.values) m.wire]);
    expect(spec('workspace.booking_rules.legend_profile').values,
        [for (final p in LegendProfile.values) p.wire]);
    expect(spec('workspace.booking_rules.advance_horizon_days').min, BookingPolicies.minHorizonDays);
    expect(spec('workspace.booking_rules.advance_horizon_days').max, BookingPolicies.maxHorizonDays);
    expect(spec('workspace.booking_rules.simultaneous_reservations').max, BookingPolicies.maxSimultaneous);
    expect(spec('workspace.dunning_rules.levels').max, 9);
  });

  test('a feature flag depends on its parent, and on nothing else', () {
    for (final e in featureManifest.values) {
      final s = _registry.firstWhere((s) => s.id == 'workspace.feature_flags.${e.feature.dbKey}');
      expect(s.dependsOn,
          [if (e.requires != null) 'workspace.feature_flags.${e.requires!.dbKey}'],
          reason: '${e.feature.name}: the dependency is the registry parent');
      expect(s.absent, TemplateAbsent.registryDefault,
          reason: '${e.feature.name}: an absent flag is the registry default, never enabled authority');
    }
  });
}

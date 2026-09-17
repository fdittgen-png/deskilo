// SPDX-License-Identifier: 0BSD
//
// #1282 S1 — the contract every builtin workspace template must pass.
//
// A builtin is readable by every signed-in user and is the first thing a
// new space is made of. A template that switches a feature on without its
// parent, orders its working hours backwards, prices a band below zero,
// strands a subscription level no band covers, or carries a bank account,
// fails here — before a person's workspace finds out.
//
// The builtins' reviewable source is `supabase/templates/<key>.json`; the
// migration that inserts each one carries the same payload, and the drift
// test below holds them together.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/l10n/lexicon.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:deskilo/features/workspace/domain/template_feature_profile.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

import 'configuration_classification_test.dart' show deployableEntityKeys;

/// What a template is checked against. Built from the real registries in
/// [TemplateContractRules.live]; the red proofs pass their own.
class TemplateContractRules {
  const TemplateContractRules({
    required this.features,
    required this.requires,
    required this.entities,
    required this.lexiconPlaceholders,
  });

  final Set<String> features;

  /// Feature name → its parent's name.
  final Map<String, String> requires;
  final Set<String> entities;

  /// Allowed lexicon key → the `{tokens}` an override must keep.
  final Map<String, List<String>> lexiconPlaceholders;

  factory TemplateContractRules.live() => TemplateContractRules(
        features: {for (final f in WorkspaceFeature.values) f.name},
        requires: {
          for (final e in featureManifest.entries)
            if (e.value.requires != null) e.key.name: e.value.requires!.name,
        },
        entities: deployableEntityKeys(),
        lexiconPlaceholders: {
          for (final e in lexiconAllowList.entries) e.key: e.value.placeholders,
        },
      );
}

/// Entities the publication allow-list denies (0229); a builtin is
/// published by definition.
const _denied = {
  'sites',
  'payment_instructions',
  'invitations',
  'document_links',
  'document_design',
};

/// Workspace keys the identity entity strips (0229).
const _strippedIdentityKeys = {
  'address', 'street', 'postal_code', 'city', 'vat_id', 'legal_id',
  'tax_exemption_reason', 'vat_account', 'invoice_legal', 'whatsapp_group',
};

/// Every way [template] breaks the contract, each naming the template and
/// the offending value.
List<String> checkTemplate(
    Map<String, dynamic> template, TemplateContractRules rules) {
  final key = '${template['key']}';
  final out = <String>[];
  void fail(String what) => out.add('$key: $what');

  if (!RegExp(r'^[a-z][a-z0-9_]{0,39}$').hasMatch(key)) {
    fail('key "$key" is not lower-case letters, digits and underscores');
  }

  final entities = [for (final e in template['entities'] as List? ?? []) '$e'];
  for (final e in entities) {
    if (!rules.entities.contains(e)) fail('entity "$e" is not deployable');
    if (_denied.contains(e)) fail('entity "$e" is never published');
  }

  final config = (template['configuration'] as Map?) ?? const {};
  final ws = Map<String, dynamic>.from(config['workspace'] as Map? ?? {});
  final tables = Map<String, dynamic>.from(config['tables'] as Map? ?? {});
  if (ws.containsKey('payment_instructions')) {
    fail('carries payment_instructions');
  }
  for (final k in _strippedIdentityKeys) {
    if (ws.containsKey(k)) fail('carries the source\'s own "$k"');
  }
  for (final t in _denied) {
    if (tables.containsKey(t)) fail('carries table "$t"');
  }

  // ── features ──
  final flags = ws['feature_flags'];
  if (flags is Map) {
    final on = <String>{};
    for (final e in flags.entries) {
      final name = '${e.key}';
      if (!rules.features.contains(name)) {
        fail('feature "$name" does not exist');
      } else if (e.value == true) {
        on.add(name);
      }
    }
    for (final f in rules.features) {
      if (!flags.containsKey(f)) fail('feature "$f" is not written explicitly');
    }
    for (final f in on) {
      final parent = rules.requires[f];
      if (parent != null && !on.contains(parent)) {
        fail('feature "$f" is on but its parent "$parent" is off');
      }
    }
  }

  // ── hours ──
  final rules0 = ws['booking_rules'];
  if (rules0 is Map) {
    final g = rules0['granularity'];
    if (g != null &&
        !BookingGranularity.values.any((v) => v.wireName == g)) {
      fail('granularity "$g" is unknown');
    }
    final start = rules0['work_start_minutes'];
    final half = rules0['half_boundary_minutes'];
    final end = rules0['work_end_minutes'];
    if (start is int && half is int && end is int &&
        !(start < half && half < end && end <= 1440)) {
      fail('working hours $start / $half / $end are not in order');
    }
    final days = rules0['open_weekdays'];
    if (days is List && days.any((d) => d is! int || d < 1 || d > 7)) {
      fail('open_weekdays $days are not within 1..7');
    }
  }

  // ── prices ──
  void nonNegative(String where, Object? v) {
    if (v != null && (v is! int || v < 0)) fail('$where price $v is not a non-negative integer');
  }

  final bands = [
    for (final b in tables['fee_bands'] as List? ?? const []) Map<String, dynamic>.from(b as Map),
  ]..sort((a, b) => (a['from_pct'] as int).compareTo(b['from_pct'] as int));
  for (var i = 0; i < bands.length; i++) {
    nonNegative('fee band', bands[i]['fee_cents']);
    if (i > 0 && (bands[i]['from_pct'] as int) < (bands[i - 1]['to_pct'] as int)) {
      fail('fee bands ${bands[i - 1]['from_pct']}–${bands[i - 1]['to_pct']} '
          'and ${bands[i]['from_pct']}–${bands[i]['to_pct']} overlap');
    }
  }
  final levels = ws['subscription_levels'];
  if (levels is Map && bands.isNotEmpty) {
    for (final pct in [...?(levels['enabled_presets'] as List?), ...?(levels['extra_levels'] as List?)]) {
      final covered = bands.any((b) =>
          (b['from_pct'] as int) < (pct as int) && pct <= (b['to_pct'] as int));
      if (!covered) fail('subscription level $pct % falls in no fee band');
    }
  }
  for (final t in ['packages', 'services', 'plans', 'accessories']) {
    for (final row in tables[t] as List? ?? const []) {
      final r = row as Map;
      for (final f in ['price_cents', 'base_fee_cents', 'supplement_cents']) {
        nonNegative('$t "${r['name']}" $f', r[f]);
      }
    }
  }
  void planPrices(Object? node, String path) {
    if (node is List) {
      for (final n in node) {
        planPrices(n, path);
      }
    } else if (node is Map) {
      final here = '$path/${node['name'] ?? ''}';
      nonNegative('plan $here', node['price_cents']);
      for (final child in ['offices', 'desks', 'seats']) {
        planPrices(node[child], here);
      }
    }
  }
  planPrices(template['floor_plan'], '');

  // ── VAT labels ──
  final vatLabels = {
    for (final r in tables['vat_rates'] as List? ?? const []) '${(r as Map)['label']}',
  };
  for (final t in ['packages', 'services', 'accessories']) {
    for (final row in tables[t] as List? ?? const []) {
      final label = (row as Map)['vat_rate'];
      if (label != null && !vatLabels.contains('$label')) {
        fail('$t "${row['name']}" names VAT rate "$label", which the template lacks');
      }
    }
  }
  final subVat = ws['subscription_vat_rate'];
  if (subVat != null && !vatLabels.contains('$subVat')) {
    fail('subscription VAT rate "$subVat" is not in the template');
  }

  // ── lexicon ──
  final lexicon = ws['lexicon'];
  if (lexicon is Map) {
    for (final locale in lexicon.entries) {
      for (final term in (locale.value as Map).entries) {
        final termKey = '${term.key}';
        final allowed = rules.lexiconPlaceholders[termKey];
        if (allowed == null) {
          fail('lexicon "$termKey" (${locale.key}) is not overridable');
          continue;
        }
        final tokens = RegExp(r'\{(\w+)\}')
            .allMatches('${term.value}')
            .map((m) => m.group(1)!)
            .toSet();
        if (!tokens.containsAll(allowed) || !allowed.toSet().containsAll(tokens)) {
          fail('lexicon "$termKey" (${locale.key}) must carry exactly '
              '${allowed.map((t) => '{$t}').join(', ')}');
        }
      }
    }
  }
  return out;
}

List<Map<String, dynamic>> _builtins() => [
      for (final f in Directory('supabase/templates')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
        Map<String, dynamic>.from(jsonDecode(f.readAsStringSync()) as Map),
    ];

void main() {
  late final rules = TemplateContractRules.live();

  test('there are builtins, and each file is named by its key', () {
    final builtins = _builtins();
    expect(builtins, isNotEmpty);
    final keys = [for (final b in builtins) b['key']];
    expect(keys.toSet().length, keys.length, reason: 'builtin keys are unique');
    for (final b in builtins) {
      expect(File('supabase/templates/${b['key']}.json').existsSync(), isTrue,
          reason: '${b['key']}: the file must be named by the key');
      expect(b['visibility'], 'builtin');
    }
  });

  test('every builtin passes the contract (#1282)', () {
    final problems = [for (final b in _builtins()) ...checkTemplate(b, rules)];
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('the builtin file and the migration that inserts it agree', () {
    final migrations = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final b in _builtins()) {
      final key = b['key'];
      final insert = RegExp(
          "insert into public\\.workspace_templates[^;]*?'$key'[^;]*?\\\$tpl\\\$(.*?)\\\$tpl\\\$",
          dotAll: true);
      final latest = migrations.lastWhere(
          (f) => insert.hasMatch(f.readAsStringSync()),
          orElse: () => fail('$key: no migration inserts this builtin'));
      final text = latest.readAsStringSync();
      final plan = jsonDecode(insert.firstMatch(text)!.group(1)!);
      final name = latest.path.split('/').last;
      expect(plan, b['floor_plan'],
          reason: '$key: supabase/templates/$key.json and $name carry '
              'different floor plans');
      // A builtin with configuration carries it in the same insert.
      final cfg = RegExp(
              "insert into public\\.workspace_templates[^;]*?'$key'[^;]*?\\\$cfg\\\$(.*?)\\\$cfg\\\$",
              dotAll: true)
          .firstMatch(text);
      final configuration = b['configuration'] as Map?;
      final carries = configuration != null &&
          ((configuration['workspace'] as Map?)?.isNotEmpty == true ||
              (configuration['tables'] as Map?)?.isNotEmpty == true);
      if (carries || cfg != null) {
        expect(cfg, isNotNull, reason: '$key: $name inserts no configuration');
        expect(jsonDecode(cfg!.group(1)!), configuration,
            reason: '$key: supabase/templates/$key.json and $name carry '
                'different configurations');
      }
    }
  });

  test('a feature profile and the flags it expands to agree', () {
    for (final b in _builtins()) {
      final expanded = expandTemplateProfile(b);
      if (expanded == null) continue;
      final flags = ((b['configuration'] as Map)['workspace'] as Map)['feature_flags'];
      expect(flags, expanded,
          reason: '${b['key']}: run `dart run tool/build_builtin_templates.dart` '
              'after changing feature_profile or the registry');
    }
  });

  group('the contract can fail, and names what failed', () {
    Map<String, dynamic> base() => <String, dynamic>{
          'key': 'fixture',
          'entities': <String>['floor_plan'],
          'configuration': <String, dynamic>{
            'workspace': <String, dynamic>{},
            'tables': <String, dynamic>{},
          },
          'floor_plan': <Object?>[],
        };

    test('a feature on with its parent off', () {
      final child = rules.requires.keys.first;
      final parent = rules.requires[child]!;
      final t = base();
      (t['configuration'] as Map)['workspace'] = <String, dynamic>{
        'feature_flags': {
          for (final f in rules.features) f: f != parent,
        },
      };
      final problems = checkTemplate(t, rules);
      expect(problems,
          contains('fixture: feature "$child" is on but its parent "$parent" is off'));
      expect(problems.every((p) => p.contains('its parent "$parent" is off')),
          isTrue,
          reason: 'only the children of the switched-off parent are named');
    });

    test('a lexicon override that drops its placeholder', () {
      final withCount = TemplateContractRules(
        features: rules.features,
        requires: rules.requires,
        entities: rules.entities,
        lexiconPlaceholders: {'seatCount': ['count']},
      );
      final t = base();
      (t['configuration'] as Map)['workspace'] = <String, dynamic>{
        'lexicon': {
          'fr': {'seatCount': 'places'},
        },
      };
      expect(checkTemplate(t, withCount).single,
          'fixture: lexicon "seatCount" (fr) must carry exactly {count}');
    });

    test('a snapshot that carries payment instructions', () {
      final t = base()
        ..['entities'] = <String>['payment_instructions'];
      (t['configuration'] as Map)['workspace'] = <String, dynamic>{
        'payment_instructions': {'iban': 'FR76…'},
      };
      final problems = checkTemplate(t, rules);
      expect(problems, contains('fixture: entity "payment_instructions" is never published'));
      expect(problems, contains('fixture: carries payment_instructions'));
    });

    test('bands that overlap or strand a level, hours out of order', () {
      final t = base();
      (t['configuration'] as Map)['workspace'] = <String, dynamic>{
        'subscription_levels': {'enabled_presets': [25, 100]},
        'booking_rules': {
          'work_start_minutes': 780,
          'half_boundary_minutes': 420,
          'work_end_minutes': 1140,
        },
      };
      (t['configuration'] as Map)['tables'] = <String, dynamic>{
        'fee_bands': [
          {'from_pct': 30, 'to_pct': 60, 'fee_cents': 5000},
          {'from_pct': 50, 'to_pct': 100, 'fee_cents': -1},
        ],
      };
      final problems = checkTemplate(t, rules);
      expect(problems, contains('fixture: subscription level 25 % falls in no fee band'));
      expect(problems, contains('fixture: fee bands 30–60 and 50–100 overlap'));
      expect(problems, contains('fixture: fee band price -1 is not a non-negative integer'));
      expect(problems, contains('fixture: working hours 780 / 420 / 1140 are not in order'));
    });
  });
}

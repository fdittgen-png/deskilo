// SPDX-License-Identifier: AGPL-3.0-or-later
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

import 'package:deskilo/features/workspace/domain/template_feature_profile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/lint/template_contract.dart' show TemplateContractRules, checkTemplate;
import 'lint_sources.dart';





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
    final migrations = sqlFiles('supabase/migrations');
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

    test('a holidays marker that is not one', () {
      final t = base();
      (t['configuration'] as Map)['holidays'] = <String, dynamic>{
        'years': 9,
        'country': 'France',
      };
      final problems = checkTemplate(t, rules);
      expect(problems, contains('fixture: holidays marker years 9 is not 1..3'));
      expect(problems,
          contains('fixture: holidays marker country "France" is not an ISO code'));
      expect(problems, contains(
          'fixture: holidays marker without the closure_days entity is never applied'));
    });
  });
}

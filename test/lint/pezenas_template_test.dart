// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1599 — the Pézenas variant is a proposal, and this is what holds it
// to what `coworking_appli_MB.PDF` actually said.
//
// The variant is owner-private: no migration inserts it and #1600
// publishes it. That leaves it with no builtin drift gate, so the two
// places it is written — the payload and the review a person reads —
// are held equal here instead.
//
// The test that matters most is the dullest: every value in the payload
// must appear in the review under one of four provenance headings. A
// reviewer who cannot tell «the report asked for 07:00–13:00» from «we
// inherited not_subject VAT» is being shown a decision dressed as a
// fact.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/workspace/domain/template_feature_profile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/build_builtin_templates.dart';
import 'template_contract_test.dart' show TemplateContractRules, checkTemplate;

const _dir = 'supabase/templates/variants';
const _key = 'pezenas_coworking';

Map<String, dynamic> _variant() => Map<String, dynamic>.from(
    jsonDecode(File('$_dir/$_key.json').readAsStringSync()) as Map);

/// The fifteen rows of the report, as the issue states them: month →
/// half-days at 50 % and at 100 %.
const _report = <String, List<int>>{
  '2026-10': [22, 44], '2026-11': [20, 40], '2026-12': [22, 44],
  '2027-01': [20, 40], '2027-02': [20, 40], '2027-03': [22, 44],
  '2027-04': [22, 44], '2027-05': [19, 38], '2027-06': [22, 44],
  '2027-07': [21, 42], '2027-08': [22, 44], '2027-09': [22, 44],
  '2027-10': [21, 42], '2027-11': [20, 40], '2027-12': [23, 46],
};

void main() {
  test('the variant passes the same contract every builtin does', () {
    expect(checkTemplate(_variant(), TemplateContractRules.live()), isEmpty);
  });

  test('it is owner-private, and stays that way until #1600 publishes it', () {
    final v = _variant();
    expect(v['visibility'], 'private');
    expect(v['key'], _key);
    final inserting = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((f) =>
            f.path.endsWith('.sql') && f.readAsStringSync().contains(_key));
    expect(inserting, isEmpty,
        reason: 'a migration would make it everyone\'s: the issue asks for an '
            'owner-private template through the existing publication flow');
  });

  test('the generic association builtin is left alone', () {
    final generic = jsonDecode(
        File('supabase/templates/association_fr.json').readAsStringSync()) as Map;
    expect(generic['visibility'], 'builtin');
    expect(generic['tags'], isNot(contains('pezenas')));
    expect(
      (generic['floor_plan'] as List).length,
      2,
      reason: 'the generic example keeps its two levels; personalising it '
          'was explicitly not what #1599 asked for',
    );
  });

  test('the feature profile and the flags it expands to agree', () {
    final v = _variant();
    expect(
      ((v['configuration'] as Map)['workspace'] as Map)['feature_flags'],
      expandTemplateProfile(v),
      reason: 'run `dart run tool/build_builtin_templates.dart`',
    );
  });

  test('the review a person reads is the payload, regenerated', () {
    expect(File('$_dir/$_key.md').readAsStringSync(), templateReview(_variant()),
        reason: 'run `dart run tool/build_builtin_templates.dart`');
  });

  group('provenance — which of these did the report actually ask for', () {
    late final rows = [
      for (final r in ((_variant()['provenance'] as Map)['rows'] as List))
        Map<String, dynamic>.from(r as Map),
    ];

    test('every row names an area, a value, a source and where it came from',
        () {
      expect(rows, isNotEmpty);
      for (final r in rows) {
        expect(r['source'],
            isIn(['explicit', 'correction', 'unresolved', 'inherited']),
            reason: '${r['area']}: unknown provenance "${r['source']}"');
        for (final field in ['area', 'value', 'where']) {
          expect('${r[field]}', isNotEmpty, reason: '${r['area']}: no $field');
        }
      }
    });

    test('all four kinds are present — a review with only one is not one', () {
      final kinds = {for (final r in rows) r['source']};
      expect(kinds, {'explicit', 'correction', 'unresolved', 'inherited'});
    });

    test('the values the PDF gave verbatim are marked explicit, and the '
        'association defaults are not', () {
      String sourceOf(String area) =>
          '${rows.firstWhere((r) => r['area'] == area)['source']}';
      expect(sourceOf('Time periods'), 'explicit');
      expect(sourceOf('Monthly fees'), 'explicit');
      expect(sourceOf('Legend'), 'explicit');
      expect(sourceOf('Visible vocabulary'), 'explicit');
      expect(sourceOf('VAT regime'), 'inherited',
          reason: 'not_subject is an association default, never a verified '
              'tax status for Pézenas');
      expect(sourceOf('Working weekdays and holidays'), 'inherited',
          reason: 'the report states monthly totals, not opening days');
      expect(sourceOf('Bureau roles'), 'inherited');
    });

    test('the physical inventory is unresolved and says so', () {
      final row = rows.firstWhere((r) => r['area'] == 'Physical inventory');
      expect(row['source'], 'unresolved');
      expect('${row['note']}', contains('eight-seat'),
          reason: 'the generic example must be named as the thing NOT used');
    });

    test('the November reading is carried as a correction, with the number '
        'it refuses', () {
      final row = rows.singleWhere((r) => r['source'] == 'correction');
      expect('${row['area']}', contains('November'));
      expect('${row['note']}', contains('40 journées'));
      expect('${row['note']}', contains('80'),
          reason: '40 whole days would be 80 half-days; the review must say '
              'that is not what is granted');
    });
  });

  test('the fifteen months are stated at both percentages, each the '
      'double of the other', () {
    final months = Map<String, dynamic>.from(
        (_variant()['acceptance'] as Map)['half_days'] as Map);
    expect(months.length, 15);
    for (final e in _report.entries) {
      expect(months[e.key], e.value, reason: e.key);
      expect((months[e.key] as List)[1], (months[e.key] as List)[0] * 2,
          reason: '${e.key}: a half-day is half a day whatever the '
              'subscription');
    }
  });

  test('the floor plan is two named levels and no invented inventory', () {
    final plan = _variant()['floor_plan'] as List;
    expect([for (final l in plan) (l as Map)['name']], ['Étage 1', 'Étage 2']);
    for (final l in plan) {
      expect((l as Map)['offices'], isEmpty,
          reason: '${l['name']}: the PDF crops establish no capacity, so the '
              'variant carries no room, table or place');
    }
  });

  test('the visible French words are exactly the ones pp.2–4 show', () {
    final lexicon = ((_variant()['configuration'] as Map)['workspace']
        as Map)['lexicon'] as Map;
    expect(lexicon['fr'], {
      'spaceKindSeat': 'Place',
      'spaceKindLevel': 'Étage',
      'shellReserveButton': 'Réservations',
      'legendFree': 'Place libre',
      'legendReserved': 'Place réservée',
      'legendMine': 'Ma place',
      'legendUnavailable': 'Place non disponible',
    });
  });
}

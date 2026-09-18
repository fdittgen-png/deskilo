// SPDX-License-Identifier: 0BSD
//
// #1289 — measure before choosing: free colour picker, or curated accents?
//
// The issue's open question is whether a workspace may pick ANY brand
// colour or must choose from a curated set. That is decided on evidence:
// derive the light, dark and warm schemes from many candidate seeds the
// way the product's own scheme is derived, run the one contrast checker
// over each, and count. The survey prints its table (the record goes
// into the issue) and pins the measured pass rate so it cannot quietly
// regress when the derivation or the checker changes.
import 'package:deskilo/app/theme.dart';
import 'package:deskilo/core/theme/contrast_audit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fifty-four seeds: a hue sweep at three lightness levels (the colours a
/// picker would hand over), plus a dozen real brand colours.
Map<String, Color> candidateSeeds() {
  final seeds = <String, Color>{};
  for (var hue = 0; hue < 360; hue += 30) {
    for (final (label, lightness) in [('dark', 0.30), ('mid', 0.45), ('light', 0.62)]) {
      seeds['hue$hue-$label'] =
          HSLColor.fromAHSL(1, hue.toDouble(), 0.7, lightness).toColor();
    }
  }
  seeds.addAll(const {
    'burnt orange (product)': Color(0xFFC2410C),
    'navy': Color(0xFF1F3A5F),
    'forest': Color(0xFF1B5E20),
    'bordeaux': Color(0xFF7B1E3A),
    'teal': Color(0xFF00695C),
    'royal blue': Color(0xFF1D4ED8),
    'purple': Color(0xFF6D28D9),
    'coral': Color(0xFFE85D4A),
    'gold': Color(0xFFD4A017),
    'charcoal': Color(0xFF374151),
    'lime': Color(0xFF84CC16),
    'pink': Color(0xFFEC4899),
    'sky': Color(0xFF38BDF8),
    'olive': Color(0xFF6B7F2A),
    'brick': Color(0xFF9A3412),
    'slate blue': Color(0xFF475569),
    'mint': Color(0xFF6EE7B7),
    'yellow': Color(0xFFFACC15),
  });
  return seeds;
}

/// The failing pairs of one seed across the three schemes, keyed by
/// scheme — through `DeskiloTheme.refusals`, the refusal itself, so the
/// survey measures exactly what the import and the picker will run.
Map<String, List<ContrastFailure>> auditSeed(Color seed) => {
      'light': auditThemeContrast(DeskiloTheme.light(brand: seed)),
      'dark': auditThemeContrast(DeskiloTheme.dark(brand: seed)),
      'warm': auditThemeContrast(DeskiloTheme.warm(brand: seed)),
    };

void main() {
  test('no brand: the derived scheme is the product scheme, pixel for pixel',
      () {
    expect(DeskiloTheme.light(brand: null).colorScheme,
        DeskiloTheme.light().colorScheme);
    expect(DeskiloTheme.dark(brand: null).colorScheme,
        DeskiloTheme.dark().colorScheme);
  });

  test('the refusal is the survey: DeskiloTheme.refusals sees exactly the '
      'failures of the three schemes', () {
    const seed = Color(0xFF1F3A5F);
    expect(
      DeskiloTheme.refusals(seed).map((f) => f.pair),
      [for (final e in auditSeed(seed).values) ...e.map((f) => f.pair)],
    );
  });

  test('the survey: how many candidate seeds pass every pair in every scheme',
      () {
    final seeds = candidateSeeds();
    final passing = <String>[];
    final failing = <String, Map<String, List<ContrastFailure>>>{};
    for (final e in seeds.entries) {
      final result = auditSeed(e.value);
      if (result.values.every((f) => f.isEmpty)) {
        passing.add(e.key);
      } else {
        failing[e.key] = result;
      }
    }
    final table = StringBuffer()
      ..writeln('| seed | light | dark | warm |')
      ..writeln('|---|---|---|---|');
    for (final e in seeds.entries) {
      final r = failing[e.key];
      String cell(String scheme) => r == null || r[scheme]!.isEmpty
          ? 'pass'
          : r[scheme]!.map((f) => f.pair.split(' on ').first).toSet().join(', ');
      table.writeln('| ${e.key} | ${cell('light')} | ${cell('dark')} | ${cell('warm')} |');
    }
    // The evidence, for the issue.
    // ignore: avoid_print
    print('brand seed survey: ${passing.length} of ${seeds.length} pass\n$table');
    expect(seeds.length, 54);
    // The product's own colour must pass — it is the baseline.
    expect(failing, isNot(contains('burnt orange (product)')));
    // Measured 2026-09-18: 54 of 54, once `_finish` checked each label
    // against the fill it ends up on. The free-picker decision rests on
    // this number; a seed that stops passing here is a decision to
    // record in #1289, not a threshold to lower.
    expect(passing.length, seeds.length,
        reason: 'candidate seeds that no longer pass: ${failing.keys}');
  });
}

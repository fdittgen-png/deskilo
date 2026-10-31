// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2578 — how far back an evolution looks is the workspace's setting
// (bi.series_months, bi.series_quarters, bi.series_years), not a literal.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/providers/bi_providers.dart';
import 'package:flutter_test/flutter_test.dart';

SettingsSet _settings([Map<String, Object> overrides = const {}]) {
  final rows = jsonDecode(
    File('assets/instance/settings_registry.json').readAsStringSync(),
  ) as List;
  final base = SettingsSet.defaults(
    [for (final r in rows) SettingDefinition.fromJson(r)],
  );
  return SettingsSet(base.definitions, {...base.effective, ...overrides});
}

void main() {
  test('the registry defaults are the old lengths: a year of months, two '
      'years of quarters, five years', () {
    final s = _settings();
    expect(biSeriesLength(BiGrain.month, s), 13);
    expect(biSeriesLength(BiGrain.quarter, s), 9);
    expect(biSeriesLength(BiGrain.year, s), 5);
  });

  test("a workspace's lengths are the ones the evolution asks for", () {
    final s = _settings({
      'bi.series_months': 7,
      'bi.series_quarters': 4,
      'bi.series_years': 3,
    });
    expect(biSeriesLength(BiGrain.month, s), 7);
    expect(biSeriesLength(BiGrain.quarter, s), 4);
    expect(biSeriesLength(BiGrain.year, s), 3);
  });

  test('without settings yet, the registry defaults stand', () {
    expect(biSeriesLength(BiGrain.month, null), 13);
    expect(biSeriesLength(BiGrain.year, null), 5);
  });
}

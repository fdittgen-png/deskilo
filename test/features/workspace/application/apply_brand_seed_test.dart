// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1289 — a colour chosen elsewhere is measured before it is stored.
import 'package:deskilo/app/theme.dart';
import 'package:deskilo/features/workspace/application/apply_brand_seed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';


import '../../../helpers/mock_providers.dart';

/// The real check, as the import passes it.
List<String> _real(int argb) =>
    [for (final f in DeskiloTheme.refusals(Color(argb))) f.pair];

void main() {
  test('a readable colour is stored upper-case, and nothing is refused',
      () async {
    final repository = FakeWorkspaceRepository();
    final refused =
        await applyImportedBrandSeed(repository, 'ws-1', '#1f3a5f', check: _real);
    expect(refused, isEmpty);
    expect(repository.brandings['ws-1'], {'seed_color': '#1F3A5F'});
  });

  test('no colour, or something that is not one: nothing written, nothing '
      'to say', () async {
    final repository = FakeWorkspaceRepository();
    expect(await applyImportedBrandSeed(repository, 'ws-1', null, check: _real), isEmpty);
    expect(await applyImportedBrandSeed(repository, 'ws-1', 'tomato', check: _real), isEmpty);
    expect(await applyImportedBrandSeed(repository, 'ws-1', '#12345', check: _real), isEmpty);
    expect(repository.brandings, isEmpty);
  });

  test('a refused colour names its pair and writes nothing', () async {
    final repository = FakeWorkspaceRepository();
    final refused = await applyImportedBrandSeed(
      repository,
      'ws-1',
      '#FACC15',
      check: (_) => ['onPrimary on primary', 'outline on surface'],
    );
    expect(refused, 'onPrimary on primary');
    expect(repository.brandings, isEmpty,
        reason: 'a colour that cannot be read is never stored');
  });

  test('every hex seed the survey measured passes the real check, so the '
      'import refuses none of them today', () async {
    // The derivation deepens each label against the fill it ends on
    // (brand_seed_survey_test: 54 of 54). The refusal is the guard that
    // would catch a derivation change before a member meets it.
    for (final seed in ['#C2410C', '#FACC15', '#1F3A5F', '#6EE7B7']) {
      final repository = FakeWorkspaceRepository();
      expect(
        await applyImportedBrandSeed(repository, 'ws-1', seed, check: _real),
        isEmpty,
        reason: seed,
      );
      expect(repository.brandings['ws-1'], {'seed_color': seed});
    }
  });
}

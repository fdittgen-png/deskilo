// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2867 — the setup steps hold together with the rest of the app: every
// step reads in all five languages, opens a route the router registers,
// and the features the levels turn on are counted against the steps that
// set them up. The count is a ratchet: it may only fall, so a level
// feature added without a step shows up as one more.
import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/features/workspace/domain/setup_levels.dart';
import 'package:deskilo/features/workspace/domain/setup_steps.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Level features no step names as its own, on 2026-10-23. Most are a
/// switch with nothing to configure; the rest wait for the Open, Run and
/// Grow steps (#2870, #2871, #2875). Lower it when a step takes one in.
const _withoutStepBaseline = 126;

Set<WorkspaceFeature> _withoutStep() {
  final levelled = {
    for (final levels in setupLevels.values)
      for (final level in levels) ...level.features,
  };
  return levelled.difference({
    for (final s in setupSteps)
      if (s.feature != null) s.feature!,
  });
}

void main() {
  test('every step has its title and its hint in all five languages', () {
    final missing = [
      for (final locale in AppLocalizations.supportedLocales)
        for (final s in setupSteps)
          if (lookupAppLocalizations(locale) case final l10n)
            for (final (what, text) in [
              ('title', l10n.setupStepTitle(s.id)),
              ('hint', l10n.setupStepHint(s.id)),
            ])
              if (text == s.id || text.trim().isEmpty)
                '${locale.languageCode}: ${s.id} $what',
    ];
    expect(missing, isEmpty, reason: 'add the step to setup_guide_*.arb');
  });

  test('every step opens a route the router registers', () {
    final unknown = [
      for (final s in setupSteps)
        if (!routeRules.any((r) => r.matches(Uri.parse(s.route).path)))
          '${s.id} → ${s.route}',
    ];
    expect(unknown, isEmpty);
  });

  test('the level features without a step only ever get fewer', () {
    final count = _withoutStep().length;
    expect(
      count,
      lessThanOrEqualTo(_withoutStepBaseline),
      reason:
          'a feature joined a level without a step: give it one, or '
          'name it as a switch with nothing to set up. Without a step: '
          '${(_withoutStep().map((f) => f.name).toList()..sort()).join(', ')}',
    );
    expect(
      count,
      _withoutStepBaseline,
      reason: 'a step took a feature in: lower _withoutStepBaseline to $count',
    );
  });

  test('the ratchet counts what it says: no feature a step names is among '
      'those without', () {
    final named = {
      for (final s in setupSteps)
        if (s.feature != null) s.feature!,
    };
    expect(named, isNotEmpty);
    expect(_withoutStep().intersection(named), isEmpty);
  });
}

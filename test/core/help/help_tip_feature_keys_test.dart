// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — a help tip names the feature it needs by its key, so core/help
// imports no feature. Each key must still be a workspace feature's: a
// misspelt key would show a scenario whose feature is off.
import 'package:deskilo/core/help/help_tips.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every tip feature key is a workspace feature key', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final known = {for (final f in WorkspaceFeature.values) f.dbKey};
    final keys = [
      for (final id in HelpHintId.values)
        for (final tip in helpHintTips(l10n, id))
          if (tip.feature != null) tip.feature!,
    ];
    expect(keys, isNotEmpty);
    expect(keys.where((k) => !known.contains(k)), isEmpty);
  });
}

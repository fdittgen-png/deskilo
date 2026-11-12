// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3788 — a title or a line that carries information is never cut: on the
// five tab pages, through the app's builder, at 390 (the web build's phone
// bar, with its menu button) and at 1440 (the desk), in the five languages,
// the app bar's title and every line the guard lists as information are
// painted whole. Measured in the app's own font. The rule bites on its
// planted fixtures in desk_guards_test.dart.
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/features/profile/providers/personal_appearance_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';
import 'experience_guards.dart';

/// The five tab pages.
const _tabs = ['/messages', '/calendar', '/directory', '/money', '/reserve'];

void main() {
  setUpAll(loadRealFonts);

  for (final locale in AppLocalizations.supportedLocales) {
    for (final width in const [390.0, 1440.0]) {
      for (final path in _tabs) {
        testWidgets('$path at ${width.toInt()} in ${locale.languageCode}: '
            'no title or information line is cut', (tester) async {
          final features = WorkspaceFeature.values.toSet();
          await pumpRoute(
            tester,
            path,
            size: Size(width, 900),
            overrides: [
              ...standardTestOverrides(
                workspace: FakeWorkspaceRepository.withWorkspace(
                  featureFlags: {for (final f in features) f.name: true},
                ),
              ),
              enabledFeaturesSyncProvider.overrideWithValue(features),
              personalLocaleProvider.overrideWithValue(locale),
              webShellProvider.overrideWithValue(true),
            ],
          );
          final details = <String>[];
          expect(
            cutInformationProblems(details: details),
            isEmpty,
            reason: details.join('\n'),
          );
          // The page's title is on screen to be read at all.
          expect(find.byType(AppBar), findsWidgets);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2454 C3 -- the Features screen shows a feature that is not available in the
// workspace's country disabled with the reason, keeps the owner's stored
// switch, and a country the feature serves shows no such note.
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/presentation/widgets/feature_capability_list.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _list(String? country) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: FeatureCapabilityList(
      rows: [featureManifest[WorkspaceFeature.recapitulativeStatement]!],
      raw: const {
        WorkspaceFeature.vatDeclarations,
        WorkspaceFeature.recapitulativeStatement,
      },
      country: country,
      showHint: false,
      onChanged: (_, {required value}) {},
    ),
  ),
);

void main() {
  testWidgets('outside the Union the row says where it is available', (tester) async {
    await tester.pumpWidget(_list('GB'));
    expect(find.textContaining('Available in the European Union'), findsOneWidget);
    // the owner's stored choice is still shown
    final tile = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('feature-recapitulativeStatement')),
    );
    expect(tile.value, isTrue);
  });

  testWidgets('inside the Union, and with no country, there is no such note', (tester) async {
    await tester.pumpWidget(_list('FR'));
    expect(find.textContaining('Available in'), findsNothing);
    await tester.pumpWidget(_list(null));
    expect(find.textContaining('Available in'), findsNothing);
  });
}

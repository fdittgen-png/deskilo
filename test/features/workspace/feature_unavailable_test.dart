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

  // #3300 — a switch the country does not offer is not offered for
  // activation; a stored ON keeps its value and can still be turned off.
  Widget mtd(String country, {required bool storedOn}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: FeatureCapabilityList(
        rows: [featureManifest[WorkspaceFeature.mtdSubmission]!],
        raw: {
          WorkspaceFeature.vatDeclarations,
          if (storedOn) WorkspaceFeature.mtdSubmission,
        },
        country: country,
        showHint: false,
        onChanged: (_, {required value}) {},
      ),
    ),
  );
  SwitchListTile mtdTile(WidgetTester tester) => tester.widget<SwitchListTile>(
    find.byKey(const ValueKey('feature-mtdSubmission')),
  );

  for (final country in ['FR', 'DE', 'US']) {
    testWidgets('MTD submission cannot be switched on in $country', (tester) async {
      await tester.pumpWidget(mtd(country, storedOn: false));
      expect(mtdTile(tester).onChanged, isNull);
      expect(find.textContaining('Available in'), findsOneWidget);
      await tester.pumpWidget(mtd(country, storedOn: true));
      expect(mtdTile(tester).value, isTrue, reason: 'the stored value is kept');
      expect(mtdTile(tester).onChanged, isNotNull, reason: 'and can be turned off');
    });
  }

  testWidgets('in the United Kingdom MTD submission is offered', (tester) async {
    await tester.pumpWidget(mtd('GB', storedOn: false));
    expect(mtdTile(tester).onChanged, isNotNull);
    expect(find.textContaining('Available in'), findsNothing);
  });
}

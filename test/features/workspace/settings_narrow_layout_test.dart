// SPDX-License-Identifier: AGPL-3.0-or-later
//
// On a phone the settings rows keep the whole width for their label, and the
// reminder rules dialog scrolls instead of spilling over its buttons.
import 'package:deskilo/core/demo/data/settings_repository.dart';
import 'package:deskilo/core/instance/settings_bundle_asset.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/presentation/widgets/dunning_rules_dialog.dart';
import 'package:deskilo/features/workspace/presentation/widgets/settings_editor.dart';
import 'package:deskilo/features/workspace/providers/settings_providers.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _long = SettingDefinition(
  key: 'purchase.payment_checker_from_units',
  type: SettingType.integer,
  defaultValue: 0,
  min: 0,
  max: 100000,
  unit: 'currency units',
  group: 'billing',
  scopes: {SettingScope.workspace},
  editPermission: 'manageBilling',
);

void main() {
  testWidgets('a settings row gives its label the full width of a phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    final store = FakeSettingsRepository([_long]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value('u1')),
          settingsRepositoryProvider.overrideWithValue(store),
          settingsBundleLoaderProvider.overrideWithValue(() async => [_long]),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SettingsEditor(
                scope: SettingScope.workspace,
                workspaceId: 'ws-1',
                canEdit: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final label = find
        .descendant(
          of: find.byKey(ValueKey('setting-${_long.key}')),
          matching: find.byType(Text),
        )
        .first;
    expect(tester.getSize(label).width, greaterThan(200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the reminder rules dialog scrolls on a small phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 520);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dunningRulesProvider.overrideWith(
            (ref) async => const DunningRules(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: Consumer(
            builder: (context, ref, _) => TextButton(
              key: const ValueKey('open'),
              onPressed: () => showDunningRulesDialog(context, ref),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(SingleChildScrollView),
      ),
      findsWidgets,
    );
    expect(find.byKey(const ValueKey('dunning-save')), findsOneWidget);
  });
}

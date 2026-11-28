// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4495 -- the setting that names the place invoice goods leave from holds a place's id, picked as site › place and never typed. A code
// (what every installation held before) is read only while exactly one place carries it; a code two places carry, a code none carries and
// a pick no longer usable are named, not guessed. Picking a place saves its id.
import 'package:deskilo/core/demo/data/settings_repository.dart';
import 'package:deskilo/core/instance/settings_bundle_asset.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/workspace/domain/setting_place.dart';
import 'package:deskilo/features/workspace/presentation/widgets/setting_place_sheet.dart';
import 'package:deskilo/features/workspace/presentation/widgets/settings_editor.dart';
import 'package:deskilo/features/workspace/providers/setting_places_provider.dart';
import 'package:deskilo/features/workspace/providers/settings_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _en = AppLocalizationsEn();

const _a = SettingPlace(id: 'aaaaaaaa-0000-4000-8000-000000000001', code: 'SHOP', path: 'Site A › Shop');
const _b = SettingPlace(id: 'bbbbbbbb-0000-4000-8000-000000000002', code: 'SHOP', path: 'Site B › Shop');
const _back = SettingPlace(id: 'cccccccc-0000-4000-8000-000000000003', code: 'BACK', path: 'Site B › Back room');
const _places = [_a, _b, _back];

final _definition = SettingDefinition(
  key: settingKeyInvoiceSalePlace,
  type: SettingType.text,
  defaultValue: 'MAIN',
  max: 40,
  unit: 'place code',
  group: 'business',
  scopes: {SettingScope.workspace},
  editPermission: 'workspaceSettings',
);

void main() {
  group('what the setting says', () {
    test('an id is the place it names', () {
      final r = placeOfSetting(_b.id, _places);
      expect((r.state, r.place), (PlaceSettingState.picked, _b));
    });

    test('a code one place carries is found by it; two places carry SHOP: named, none chosen', () {
      expect(placeOfSetting('BACK', _places).state, PlaceSettingState.fromCode);
      final shop = placeOfSetting('SHOP', _places);
      expect((shop.state, shop.place, shop.code), (PlaceSettingState.ambiguous, null, 'SHOP'));
    });

    test('a code no place carries, and a pick that is gone, are missing; empty is the code MAIN', () {
      expect(placeOfSetting('NOWHERE', _places).state, PlaceSettingState.missing);
      expect(placeOfSetting('dddddddd-0000-4000-8000-000000000009', _places).state, PlaceSettingState.missing);
      expect(placeOfSetting('', _places).code, 'MAIN');
    });

    test('and it is said in words, with the way out', () {
      expect(placeSettingText(_en, _b.id, _places), 'Site B › Shop');
      expect(placeSettingText(_en, 'SHOP', _places), contains('several places'));
      expect(placeSettingText(_en, 'SHOP', _places), contains('refused until you do'));
      expect(placeSettingText(_en, 'BACK', _places), contains('Site B › Back room'));
    });
  });

  testWidgets('the owner picks Site B / Shop from a list and the setting saves its id', (tester) async {
    final store = FakeSettingsRepository([_definition]);
    await store.setValue(workspaceId: 'ws-1', key: settingKeyInvoiceSalePlace, value: 'SHOP');
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value('u1')),
          settingsRepositoryProvider.overrideWithValue(store),
          settingsBundleLoaderProvider.overrideWithValue(() async => [_definition]),
          settingPlacesProvider.overrideWith((ref, ws) async => _places),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(child: SettingsEditor(scope: SettingScope.workspace, workspaceId: 'ws-1', canEdit: true)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('several places'), findsOneWidget, reason: 'the ambiguity is on the setting');

    await tester.tap(find.byKey(const ValueKey('setting-edit-stock.invoice_sale_place')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('setting-value')), findsNothing, reason: 'a place is picked, never typed');
    await tester.tap(find.byKey(const ValueKey('setting-place')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Site B › Shop').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setting-place-save')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(store.writes.last.key, settingKeyInvoiceSalePlace);
    expect(store.writes.last.value, _b.id);
    expect(find.text('Site B › Shop'), findsOneWidget);
  });
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2552 XPRIV-01 — Me › Account's private-values switch writes the choice
// on the device AND as the personal account's default (never a workspace
// override, even with the workspace scope on), and the masked values on
// screen follow it.
import 'package:deskilo/app/private_values_wiring.dart';
import 'package:deskilo/core/demo/data/personal_preferences_repository.dart';
import 'package:deskilo/core/privacy/private_values.dart';
import 'package:deskilo/core/ui/private_value.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:deskilo/features/profile/domain/personal_preferences.dart';
import 'package:deskilo/features/profile/presentation/widgets/private_values_tile.dart';
import 'package:deskilo/features/profile/providers/personal_preferences_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

class _MemoryStore implements PrivateValuesStore {
  _MemoryStore([this.value]);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? value) async => this.value = value;
}

const _tile = ValueKey('settings-private-values');

Future<void> _pump(
  WidgetTester tester,
  FakePersonalPreferencesRepository repository,
  _MemoryStore device,
) async {
  await pumpApp(
    tester,
    const Scaffold(
      body: Column(
        children: [
          PrivateValuesTile(),
          PrivateValue(revealKey: ValueKey('reveal'), child: Text('EUR 12.34')),
        ],
      ),
    ),
    overrides: [
      ...standardTestOverrides(personalPreferences: repository),
      personalShellEnabledProvider.overrideWithValue(true),
      privateValuesStoreProvider.overrideWithValue(device),
      privateValuesFromAccount,
    ],
  );
  await tester.pumpAndSettle();
}

bool _switchOn(WidgetTester tester) =>
    tester.widget<SwitchListTile>(find.byKey(_tile)).value;

void main() {
  testWidgets('a new account starts masked; turning it off writes the device '
      'and the account, and the values show', (tester) async {
    final repository = FakePersonalPreferencesRepository();
    final device = _MemoryStore();
    await _pump(tester, repository, device);
    expect(_switchOn(tester), isTrue);
    expect(find.text('EUR 12.34'), findsNothing);
    await tester.tap(find.byKey(_tile));
    await tester.pumpAndSettle();
    expect(device.value, PrivateValuesChoice.shown);
    expect(
      repository.defaults[PersonalPreference.privateValues],
      PrivateValuesChoice.shown,
    );
    expect(repository.overrides, isEmpty);
    expect(_switchOn(tester), isFalse);
    expect(find.text('EUR 12.34'), findsOneWidget);
    await tester.tap(find.byKey(_tile));
    await tester.pumpAndSettle();
    expect(
      repository.defaults[PersonalPreference.privateValues],
      PrivateValuesChoice.masked,
    );
    expect(find.text('EUR 12.34'), findsNothing);
  });

  testWidgets('an explicit account choice is kept over the device', (
    tester,
  ) async {
    final repository = FakePersonalPreferencesRepository()
      ..defaults[PersonalPreference.privateValues] = PrivateValuesChoice.shown;
    await _pump(tester, repository, _MemoryStore(PrivateValuesChoice.masked));
    expect(_switchOn(tester), isFalse);
    expect(find.text('EUR 12.34'), findsOneWidget);
  });

  testWidgets('the workspace scope switch never scopes the mask', (
    tester,
  ) async {
    final repository = FakePersonalPreferencesRepository();
    await _pump(tester, repository, _MemoryStore());
    ProviderScope.containerOf(tester.element(find.byKey(_tile)))
        .read(workspacePreferenceEditingProvider.notifier)
        .set(value: true);
    await tester.tap(find.byKey(_tile));
    await tester.pumpAndSettle();
    expect(repository.overrides, isEmpty);
    expect(
      repository.defaults[PersonalPreference.privateValues],
      PrivateValuesChoice.shown,
    );
  });

  testWidgets('without the personal shell the switch is not offered', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(body: PrivateValuesTile()),
      overrides: [privateValuesStoreProvider.overrideWithValue(_MemoryStore())],
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_tile), findsNothing);
  });

  test('the account map keeps the key, read fail-closed', () {
    final p = PersonalPreferences.fromJson({
      'defaults': {'private_values': 'shown'},
      'overrides': <String, Object?>{},
    });
    expect(p.defaults[PersonalPreference.privateValues], 'shown');
  });
}

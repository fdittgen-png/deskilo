// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3647 — the language of letters and notifications is its own preference:
// chosen in Region & formats, it is stored and survives any later change of
// the interface language; while it follows the app (every account that never
// chose), the interface language keeps writing it as before and a stored
// value stays. A refused save is said in words and changes nothing; the
// next try saves.
import 'package:deskilo/core/demo/data/personal_preferences_repository.dart';
import 'package:deskilo/core/locale/locale_controller.dart';
import 'package:deskilo/features/profile/domain/personal_preferences.dart';
import 'package:deskilo/features/profile/presentation/widgets/preference_scope_controls.dart';
import 'package:deskilo/features/profile/presentation/widgets/regional_formats_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

class InMemoryLocaleStore implements LocaleStore {
  String? code;

  @override
  Future<String?> read() async => code;

  @override
  Future<void> write(String? languageCode) async => code = languageCode;
}

/// A store that refuses every write while [refuse] is set, as a server
/// that rejects the patch does: nothing of it is kept.
class _RefusingPreferences extends FakePersonalPreferencesRepository {
  bool refuse = false;

  @override
  Future<void> patch(Map<String, String?> values, {String? workspaceId}) async {
    if (refuse) throw StateError('invalid preference value');
    await super.patch(values, workspaceId: workspaceId);
  }
}

Future<WidgetRef> _formats(
  WidgetTester tester,
  FakePersonalPreferencesRepository repository,
) async {
  late WidgetRef captured;
  await pumpApp(
    tester,
    Consumer(
      builder: (context, ref, _) {
        captured = ref;
        return const RegionalFormatsScreen();
      },
    ),
    size: const Size(800, 1600),
    overrides: [
      ...standardTestOverrides(
        auth: FakeAuthRepository.signedIn(),
        personalPreferences: repository,
      ),
      // No platform channel in a widget test: the device copy in memory.
      localeStoreProvider.overrideWithValue(InMemoryLocaleStore()),
    ],
  );
  await tester.pumpAndSettle();
  return captured;
}

Future<void> _choose(WidgetTester tester, String option) async {
  await tester.tap(find.byKey(ValueKey('document-language-option-$option')));
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('document-language')));
  await tester.tap(find.byKey(const ValueKey('document-language')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a chosen language is stored and survives an interface-language '
      'change', (tester) async {
    final repository = FakePersonalPreferencesRepository();
    final ref = await _formats(tester, repository);
    expect(find.text("Follows the app's language"), findsOneWidget);

    await _open(tester);
    await _choose(tester, 'it');
    expect(repository.defaults[PersonalPreference.documentLocale], 'it');
    expect(
      repository.defaults[PersonalPreference.documentLocaleMode],
      'chosen',
    );
    expect(find.byType(SimpleDialog), findsNothing);
    expect(find.text('Italian'), findsOneWidget);

    await savePersonalLanguage(ref, const Locale('fr'), workspaceOnly: false);
    await tester.pumpAndSettle();
    expect(repository.defaults[PersonalPreference.uiLocale], 'fr');
    expect(
      repository.defaults[PersonalPreference.documentLocale],
      'it',
      reason: 'once chosen, the interface language never writes it',
    );
  });

  testWidgets('while it follows the app, the interface language writes it as '
      'before, and a stored value stays until then', (tester) async {
    final repository = FakePersonalPreferencesRepository()
      ..defaults[PersonalPreference.documentLocale] = 'de';
    final ref = await _formats(tester, repository);
    expect(find.text("Follows the app's language"), findsOneWidget);
    expect(repository.defaults[PersonalPreference.documentLocale], 'de');

    await savePersonalLanguage(ref, const Locale('es'), workspaceOnly: false);
    await tester.pumpAndSettle();
    expect(repository.defaults[PersonalPreference.documentLocale], 'es');
  });

  testWidgets('following the app again takes the app language and lets it '
      'write again', (tester) async {
    final repository = FakePersonalPreferencesRepository()
      ..defaults[PersonalPreference.uiLocale] = 'fr'
      ..defaults[PersonalPreference.documentLocale] = 'it'
      ..defaults[PersonalPreference.documentLocaleMode] = 'chosen';
    final ref = await _formats(tester, repository);
    await _open(tester);
    await _choose(tester, 'follows');
    expect(
      repository.defaults[PersonalPreference.documentLocaleMode],
      'follows',
    );
    expect(repository.defaults[PersonalPreference.documentLocale], 'fr');

    await savePersonalLanguage(ref, const Locale('de'), workspaceOnly: false);
    await tester.pumpAndSettle();
    expect(repository.defaults[PersonalPreference.documentLocale], 'de');
  });

  testWidgets('a refused save is said in words and changes nothing; the next '
      'try saves', (tester) async {
    final repository = _RefusingPreferences()
      ..defaults[PersonalPreference.documentLocale] = 'de'
      ..refuse = true;
    await _formats(tester, repository);
    await _open(tester);
    await _choose(tester, 'es');
    expect(
      find.text('Could not save your preferences. Please try again.'),
      findsOneWidget,
    );
    expect(repository.defaults[PersonalPreference.documentLocale], 'de');
    expect(
      repository.defaults.containsKey(PersonalPreference.documentLocaleMode),
      isFalse,
    );
    expect(
      find.byType(SimpleDialog),
      findsOneWidget,
      reason: 'the choices stay open to try again',
    );

    repository.refuse = false;
    await _choose(tester, 'es');
    expect(repository.defaults[PersonalPreference.documentLocale], 'es');
    expect(
      repository.defaults[PersonalPreference.documentLocaleMode],
      'chosen',
    );
    expect(find.byType(SimpleDialog), findsNothing);
  });

  test('the workspace reset never sends the account-only mode', () {
    expect(
      PersonalPreference.workspaceKeys,
      isNot(contains(PersonalPreference.documentLocaleMode)),
    );
    expect(
      PersonalPreference.keys,
      contains(PersonalPreference.documentLocaleMode),
    );
  });
}

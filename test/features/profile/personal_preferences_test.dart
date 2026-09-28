// SPDX-License-Identifier: AGPL-3.0-or-later
// #1791: workspace choices inherit independently and the existing format screen
// writes/reset real scoped preferences rather than changing personal defaults.
import 'package:deskilo/core/demo/data/personal_preferences_repository.dart';
import 'package:deskilo/core/i18n/format_prefs.dart';
import 'package:deskilo/core/i18n/regional_formats_section.dart';
import 'package:deskilo/features/profile/domain/personal_preferences.dart';
import 'package:deskilo/features/profile/providers/personal_preferences_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/mock_providers.dart';

void main() {
  test('explicit workspace values win, reset resumes latest default', () async {
    final repository = FakePersonalPreferencesRepository();
    await repository.patch({PersonalPreference.clock: '24h', PersonalPreference.theme: 'dark'});
    await repository.patch({PersonalPreference.clock: '12h'}, workspaceId: 'a');
    await repository.patch({PersonalPreference.theme: 'light'}, workspaceId: 'b');
    await repository.patch({PersonalPreference.clock: 'auto'});
    expect((await repository.read(workspaceId: 'a')).effective,
      {PersonalPreference.clock: '12h', PersonalPreference.theme: 'dark'});
    expect((await repository.read(workspaceId: 'b')).effective,
      {PersonalPreference.clock: 'auto', PersonalPreference.theme: 'light'});
    await repository.patch({PersonalPreference.clock: null}, workspaceId: 'a');
    expect((await repository.read(workspaceId: 'a')).effective[PersonalPreference.clock], 'auto');
  });

  test('a response cannot smuggle authorization settings into preferences', () {
    final preferences = PersonalPreferences.fromJson({
      'defaults': {'clock': '24h', 'is_owner': 'true'},
      'overrides': {'clock': '12h', 'theme': false},
    });
    expect(preferences.effective, {'clock': '12h'});
    expect(preferences.formats(FormatPrefs.defaults).clock, ClockPref.h12);
  });

  testWidgets('existing formats screen edits only this workspace and restores defaults', (tester) async {
    final repository = FakePersonalPreferencesRepository();
    repository.defaults[PersonalPreference.clock] = '24h';
    final workspace = FakeWorkspaceRepository.withWorkspace();
    await tester.pumpWidget(ProviderScope(overrides: [
      ...standardTestOverrides(workspace: workspace, pinFormats: false, personalPreferences: repository),
    ], child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RegionalFormatsScreen(),
    )));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(RegionalFormatsScreen)));
    final id = container.read(currentWorkspaceProvider).value!.id;
    await tester.tap(find.byKey(const ValueKey('preferences-workspace-only')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('12h'));
    await tester.tap(find.text('12h'));
    await tester.pumpAndSettle();
    expect(repository.defaults[PersonalPreference.clock], '24h');
    expect(repository.overrides[id], {PersonalPreference.clock: '12h'});
    await tester.ensureVisible(find.byKey(const ValueKey('preferences-reset-workspace')));
    await tester.tap(find.byKey(const ValueKey('preferences-reset-workspace')));
    await tester.pumpAndSettle();
    expect(repository.overrides[id], isEmpty);
    expect(container.read(personalSettingsProvider).value!.effective[PersonalPreference.clock], '24h');
    expect(tester.takeException(), isNull);
  });
}

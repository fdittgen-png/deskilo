// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/locale/locale_controller.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/profile_providers.dart';
import '../../domain/personal_preferences.dart';
import '../../providers/personal_preferences_providers.dart';

/// Optional scope in the existing settings pages; defaults remain the initial
/// editing scope so an upgrade changes neither appearance nor ordinary tasks.
class PreferenceScopeControls extends ConsumerWidget {
  const PreferenceScopeControls({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(personalPreferenceContextProvider);
    if (scope.account == null || scope.workspace == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final scoped = ref.watch(workspacePreferenceEditingProvider);
    final overrides = ref.watch(personalSettingsProvider).value?.overrides ?? const {};
    return Column(children: [
      SwitchListTile(
        key: const ValueKey('preferences-workspace-only'),
        title: Text(l10n?.preferencesWorkspaceOnly ?? 'Only for this workspace'),
        subtitle: Text(l10n?.preferencesScopeHint ?? 'Language, appearance and regional formats. Off: edit my defaults.'),
        value: scoped,
        onChanged: ref.read(workspacePreferenceEditingProvider.notifier).set,
      ),
      if (scoped && overrides.isNotEmpty)
        TextButton(
          key: const ValueKey('preferences-reset-workspace'),
          onPressed: () => runGuarded(context, domain: 'profile',
            message: 'reset workspace preferences failed',
            errorText: l10n?.preferencesSaveFailed ?? 'Could not save your preferences. Please try again.',
            action: ref.read(personalSettingsProvider.notifier).resetWorkspace),
          child: Text(l10n?.preferencesUseDefaults ?? 'Use my defaults'),
        ),
    ]);
  }
}

Future<void> savePersonalLanguage(WidgetRef ref, Locale? locale) async {
  final scoped = ref.read(workspacePreferenceEditingProvider);
  final account = ref.read(personalPreferenceContextProvider).account;
  final controller = ref.read(localeControllerProvider.notifier);
  if (account != null) {
    await ref.read(personalSettingsProvider.notifier).save({
      PersonalPreference.uiLocale: locale?.languageCode ?? '',
      PersonalPreference.documentLocale: locale?.languageCode ?? '',
    }, workspaceOnly: scoped);
  }
  if (!scoped && ref.context.mounted && ref.read(personalPreferenceContextProvider).account == account) await controller.set(locale);
}

Future<void> savePersonalTheme(WidgetRef ref, ThemeMode? mode) async {
  final scoped = ref.read(workspacePreferenceEditingProvider);
  final account = ref.read(personalPreferenceContextProvider).account;
  final controller = ref.read(themeControllerProvider.notifier);
  if (account != null) {
    await ref.read(personalSettingsProvider.notifier).save({
      PersonalPreference.theme: mode?.name ?? 'system',
    }, workspaceOnly: scoped);
  }
  if (!scoped && ref.context.mounted && ref.read(personalPreferenceContextProvider).account == account) await controller.set(mode);
}

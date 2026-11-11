// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/locale/locale_controller.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/trace/guarded.dart';
import '../../domain/personal_preferences.dart';
import '../../providers/personal_preferences_providers.dart';
import '../../providers/profile_providers.dart';

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
    final l10n = context.l10n;
    final scoped = ref.watch(workspacePreferenceEditingProvider);
    final overrides = ref.watch(personalSettingsProvider).value?.overrides ?? const {};
    return Column(children: [
      SwitchListTile(
        key: const ValueKey('preferences-workspace-only'),
        title: Text(l10n.preferencesWorkspaceOnly),
        subtitle: Text(l10n.preferencesScopeHint),
        value: scoped,
        onChanged: (v) =>
            ref.read(workspacePreferenceEditingProvider.notifier).set(value: v),
      ),
      if (scoped && overrides.isNotEmpty)
        TextButton(
          key: const ValueKey('preferences-reset-workspace'),
          onPressed: () => runGuarded(context, domain: 'profile',
            message: 'reset workspace preferences failed',
            errorText: l10n.preferencesSaveFailed,
            action: ref.read(personalSettingsProvider.notifier).resetWorkspace),
          child: Text(l10n.preferencesUseDefaults),
        ),
    ]);
  }
}

/// [workspaceOnly] overrides the scope switch (#1823: Me always edits
/// the account's defaults); null follows it.
Future<void> savePersonalLanguage(WidgetRef ref, Locale? locale, {bool? workspaceOnly}) async {
  final bool scoped = workspaceOnly ?? ref.read(workspacePreferenceEditingProvider);
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

Future<void> savePersonalTheme(WidgetRef ref, ThemeMode? mode, {bool? workspaceOnly}) async {
  final bool scoped = workspaceOnly ?? ref.read(workspacePreferenceEditingProvider);
  final account = ref.read(personalPreferenceContextProvider).account;
  final controller = ref.read(themeControllerProvider.notifier);
  if (account != null) {
    await ref.read(personalSettingsProvider.notifier).save({
      PersonalPreference.theme: mode?.name ?? 'system',
    }, workspaceOnly: scoped);
  }
  if (!scoped && ref.context.mounted && ref.read(personalPreferenceContextProvider).account == account) await controller.set(mode);
}

// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/country_names.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/personal_preferences.dart';
import '../../providers/personal_preferences_providers.dart';
import 'preference_scope_controls.dart';

/// Radio value of "follows the app's language" (the stored choice is null).
const _follows = 'follows';

/// The language reminders, member documents and push messages are written
/// in: it follows the app's language, or the person chose one of the
/// languages the app ships. An account's own setting, never a business's.
class DocumentLanguageTile extends ConsumerWidget {
  const DocumentLanguageTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final chosen = chosenDocumentLanguage(
      ref.watch(personalSettingsProvider).value,
    );
    return ListTile(
      key: const ValueKey('document-language'),
      leading: const Icon(Icons.mail_outline),
      title: Text(l10n.documentLanguageTitle),
      subtitle: Text(
        chosen == null
            ? l10n.documentLanguageFollows
            : localizedLanguageName(l10n, chosen),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => _DocumentLanguageDialog(current: chosen),
      ),
    );
  }
}

/// The language the person chose for letters and notifications, or null
/// while it follows the app's language.
String? chosenDocumentLanguage(PersonalPreferences? stored) {
  final defaults = stored?.defaults ?? const <String, String>{};
  final mode = DocumentLocaleMode.fromWire(
    defaults[PersonalPreference.documentLocaleMode],
  );
  final language = defaults[PersonalPreference.documentLocale] ?? '';
  return mode == DocumentLocaleMode.chosen && language.isNotEmpty
      ? language
      : null;
}

class _DocumentLanguageDialog extends ConsumerWidget {
  const _DocumentLanguageDialog({required this.current});

  final String? current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SimpleDialog(
      title: Text(l10n.documentLanguageTitle),
      children: [
        Padding(
          padding: AppSpacing.xlH,
          child: Text(l10n.documentLanguageHint),
        ),
        RadioGroup<String>(
          groupValue: current ?? _follows,
          onChanged: (value) async {
            final saved = await runGuarded(
              context,
              domain: 'profile',
              message: 'save document language failed',
              errorText: l10n.preferencesSaveFailed,
              action: () => saveDocumentLanguage(
                ref,
                value == null || value == _follows ? null : value,
              ),
            );
            // A refusal keeps the choices open: nothing changed, try again.
            if (saved && context.mounted) Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                key: const ValueKey('document-language-option-follows'),
                value: _follows,
                title: Text(l10n.documentLanguageFollows),
              ),
              for (final locale in AppLocalizations.supportedLocales)
                RadioListTile<String>(
                  key: ValueKey(
                    'document-language-option-${locale.languageCode}',
                  ),
                  value: locale.languageCode,
                  title: Text(localizedLanguageName(l10n, locale.languageCode)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

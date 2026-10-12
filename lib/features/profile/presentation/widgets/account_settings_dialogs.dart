// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The dialogs of My account (#147 language, #160 theme, 0060 address,
// #969 navigation), moved with the tiles that open them (#1823).
part of '../screens/settings_screen.dart';

/// Endonyms are proper nouns, identical in every UI language — deliberately
/// const strings, not l10n keys (#147). Order matches the issue spec.
const _endonyms = <String, String>{
  'de': 'Deutsch',
  'en': 'English',
  'fr': 'Français',
  'es': 'Español',
  'it': 'Italiano',
};

/// Radio sentinel for "follow the system locale" (the override itself is
/// null, which a radio group cannot use as a selectable value).
const _systemDefault = 'system';

/// Radio picker for the app language. Selecting an option applies it
/// instantly (the MaterialApp rebuilds via [localeControllerProvider])
/// and persists it locally.
class _LanguageDialog extends ConsumerWidget {
  const _LanguageDialog({this.defaultsOnly = false});

  /// #1823 — Me edits the account's defaults whatever a space's settings
  /// were last switched to; only a space's own screen edits its exception.
  final bool defaultsOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current =
        ref.watch(personalLocaleProvider)?.languageCode ??
        _systemDefault;
    return SimpleDialog(
      title: Text(l10n.languageTitle),
      children: [
        RadioGroup<String>(
          key: const ValueKey('account-settings-dialogs-preferences-save-failed'),
          groupValue: current,
          onChanged: (code) async {
            await runGuarded(context, domain: 'profile', message: 'save language failed',
              errorText: l10n.preferencesSaveFailed,
              action: () => savePersonalLanguage(ref, code == null || code == _systemDefault ? null : Locale(code),
                  workspaceOnly: defaultsOnly ? false : null));
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                value: _systemDefault,
                title: Text(l10n.languageSystemDefault),
              ),
              for (final entry in _endonyms.entries)
                RadioListTile<String>(
                  value: entry.key,
                  // Render each endonym under its own locale.
                  title: Text(entry.value, locale: Locale(entry.key)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Edits the member's postal address (0060) — printed on invoices;
/// blank clears it.
class _AddressDialog extends ConsumerStatefulWidget {
  const _AddressDialog();

  @override
  ConsumerState<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends ConsumerState<_AddressDialog> {
  late final TextEditingController _controller;
  late final TextEditingController _vatId;
  String? _countryCode;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(myProfileProvider).value;
    _controller = TextEditingController(text: profile?.address ?? '');
    _vatId = TextEditingController(text: profile?.vatId ?? '');
    // 0069 — the country an EN 16931 invoice must state about the
    // customer (BT-55); unset means "wherever the workspace is".
    final stored = profile?.countryCode ?? '';
    _countryCode = stored.isEmpty ? null : stored;
  }

  @override
  void dispose() {
    _controller.dispose();
    _vatId.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // #1514 — this form was prefilled from the recording seam.
    if (refusedWhileRecording(context, ref)) return;
    final l10n = context.l10n;
    setState(() => _saving = true);
    if (!await runGuarded(
      context,
      domain: 'profile',
      message: 'address update failed',
      errorText: l10n.meAddressSaveFailed,
      action: () async {
        // One write: one invoice block (#1532, and its repository doc).
        await ref.read(myProfileEditsProvider).saveInvoiceIdentity(
              address: _controller.text,
              countryCode: _countryCode ?? '',
              vatId: _vatId.text,
            );
      },
    )) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    ref.invalidate(myProfileProvider);
    if (!mounted) return;
    Navigator.of(context).pop();
    AppSnack.success(context, l10n.addressSaved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.addressTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('address-field'),
              controller: _controller,
              maxLines: 3,
              maxLength: 400,
              decoration: InputDecoration(
                labelText: l10n.addressTitle,
              ),
            ),
            // 0069 — what the e-invoice needs beyond the street: the
            // country, and the VAT id of a member who invoices as a
            // business.
            DropdownButtonFormField<String>(
              key: const ValueKey('address-country'),
              initialValue: _countryCode,
              isExpanded: true,
              items: [
                for (final country in CountryCatalog.countries)
                  DropdownMenuItem(
                    value: country.code,
                    child: Text(localizedCountryName(l10n, country.code)),
                  ),
              ],
              onChanged: (value) => setState(() => _countryCode = value),
              decoration: InputDecoration(
                labelText: l10n.addressCountryLabel,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('address-vat-id'),
              controller: _vatId,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: l10n.addressVatIdLabel,
                suffixIcon: HelpDot(
                  l10n.helpTopicSettings,
                  anchor: HelpAnchor.profileVatId,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('account-settings-dialogs-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('address-save'),
          onPressed: _saving ? null : _save,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

/// Radio picker for the app theme (#160). Selecting an option applies it
/// instantly (the MaterialApp rebuilds via [themeControllerProvider])
/// and persists it locally. [ThemeMode.system] doubles as the radio
/// sentinel for "no override" (the override itself is null).
class _ThemeDialog extends ConsumerWidget {
  const _ThemeDialog({this.defaultsOnly = false});

  /// #1823 — see [_LanguageDialog.defaultsOnly].
  final bool defaultsOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current =
        ref.watch(personalThemeProvider) ?? ThemeMode.system;
    return SimpleDialog(
      title: Text(l10n.themeTitle),
      children: [
        RadioGroup<ThemeMode>(
          key: const ValueKey('account-settings-dialogs-preferences-save-failed-2'),
          groupValue: current,
          onChanged: (mode) async {
            await runGuarded(context, domain: 'profile', message: 'save theme failed',
              errorText: l10n.preferencesSaveFailed,
              action: () => savePersonalTheme(ref, mode == null || mode == ThemeMode.system ? null : mode,
                  workspaceOnly: defaultsOnly ? false : null));
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                value: ThemeMode.system,
                title: Text(l10n.themeSystem),
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.light,
                title: Text(l10n.themeLight),
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.dark,
                title: Text(l10n.themeDark),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Guilhem MARTIN · SASU KaloA, 209 rue Jean Bart…, 31670 LABÈGE" — the
/// tile's one-glance summary; null when nothing is filled in yet.
String? _identitySummary(Profile? profile) {
  if (profile == null || profile.identity.isEmpty) return null;
  final parts = [
    profile.fullName,
    profile.postalBlock().replaceAll('\n', ', '),
  ].where((p) => p.isNotEmpty);
  return parts.isEmpty ? null : parts.join(' · ');
}

/// #969 — radio picker for the shell's navigation. Null (the first
/// option) is the platform's default; a choice applies instantly, the
/// shell watches the controller.
class _NavigationDialog extends ConsumerWidget {
  const _NavigationDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(navigationStyleControllerProvider).value;
    return SimpleDialog(
      title: Text(l10n.navigationTitle),
      children: [
        RadioGroup<NavigationStyle?>(
          key: const ValueKey('account-settings-dialogs-navigation-default'),
          groupValue: current,
          onChanged: (style) {
            unawaited(ref.read(navigationStyleControllerProvider.notifier).set(style));
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<NavigationStyle?>(
                key: const ValueKey('navigation-default'),
                value: null,
                title: Text(
                    l10n.navigationDefault),
              ),
              RadioListTile<NavigationStyle?>(
                key: const ValueKey('navigation-classic'),
                value: NavigationStyle.classic,
                title: Text(l10n.navigationClassic),
              ),
              RadioListTile<NavigationStyle?>(
                key: const ValueKey('navigation-menu'),
                value: NavigationStyle.menu,
                title: Text(l10n.navigationMenu),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

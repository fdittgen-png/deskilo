// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/profile/providers/profile_providers.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_spacing.dart';
import '../time/clock.dart';
import '../trace/guarded.dart';
import 'app_format.dart';
import 'format_controller.dart';
import 'format_prefs.dart';
import 'locale_names.dart';

/// Settings → Region & formats (#711): the member's own numbers, dates,
/// clock and time zone. The tile previews what the choices add up to;
/// the screen behind it edits them.
class RegionalFormatsSection extends ConsumerWidget {
  const RegionalFormatsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final format = ref.watch(appFormatProvider);
    final now = ref.watch(clockProvider).now();
    return ListTile(
      key: const ValueKey('regional-formats'),
      leading: const Icon(Icons.language_outlined),
      title: Text(l10n?.regionalFormatsTitle ?? 'Region & formats'),
      subtitle: Text(
        '${format.money(123456)} · ${format.date(now)} · ${format.time(now)}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/formats'),
    );
  }
}

/// #734 — a SCREEN, not a sheet: a long picker in a tile's trailing slot
/// squeezed the tile's own words into a one-character column, and a
/// full-height sheet ran under the status bar. Each choice now owns a
/// full-width row; the format picker is a list with a check mark, the
/// way a phone picks a language.
class RegionalFormatsScreen extends ConsumerWidget {
  const RegionalFormatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final prefs =
        ref.watch(myProfileProvider).value?.formatPrefs ?? FormatPrefs.defaults;
    final format = ref.watch(appFormatProvider);
    final now = ref.watch(clockProvider).now();

    Future<void> save(FormatPrefs next) => runGuarded(
          context,
          domain: 'profile',
          message: 'save format prefs failed',
          errorText: l10n?.workspaceGenericError ??
              'Something went wrong. Please try again.',
          action: () => ref.read(profileRepositoryProvider).setFormatPrefs(next),
        ).then((_) => ref.invalidate(myProfileProvider));

    final localeLabel = prefs.formatLocale.isEmpty
        ? (l10n?.regionalFormatLocaleAuto(formatLocaleLabel(l10n, format.locale)) ??
            'Follows the app language (${format.locale})')
        : formatLocaleLabel(l10n, prefs.formatLocale);

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.regionalFormatsTitle ?? 'Region & formats')),
      body: ListView(
        children: [
          // The preview: what the three choices below ADD UP to, on one
          // line, updated as they change.
          Card(
            margin: AppSpacing.lgAll,
            child: Padding(
              padding: AppSpacing.mdAll,
              child: Text(
                '${format.money(123456)} · ${format.date(now)} · ${format.time(now)}',
                key: const ValueKey('regional-sheet-preview'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          ListTile(
            key: const ValueKey('regional-locale'),
            leading: const Icon(Icons.language_outlined),
            title: Text(l10n?.regionalFormatLocale ?? 'Numbers & dates'),
            subtitle: Text(localeLabel),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickLocale(context, l10n, prefs, save),
          ),
          ListTile(
            key: const ValueKey('regional-clock'),
            leading: const Icon(Icons.schedule_outlined),
            title: Text(l10n?.regionalClock ?? 'Clock'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: SegmentedButton<ClockPref>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: ClockPref.auto,
                  label: Text(l10n?.regionalClockAuto ?? 'Auto'),
                ),
                ButtonSegment(
                  value: ClockPref.h24,
                  label: Text(l10n?.regionalClock24h ?? '24h'),
                ),
                ButtonSegment(
                  value: ClockPref.h12,
                  label: Text(l10n?.regionalClock12h ?? '12h'),
                ),
              ],
              selected: {prefs.clock},
              onSelectionChanged: (s) => save(prefs.copyWith(clock: s.first)),
            ),
          ),
          SwitchListTile(
            key: const ValueKey('regional-device-zone'),
            secondary: const Icon(Icons.public_outlined),
            title: Text(l10n?.regionalDeviceZone ?? 'Show times in my time zone'),
            // Says what the default IS, because "workspace time" only
            // means something once you know the workspace is elsewhere.
            subtitle: Text(
              l10n?.regionalDeviceZoneHint ??
                  'Off: times show in the workspace\'s zone, the one bookings '
                      'are made in. On: your device\'s, labelled where it '
                      'differs.',
            ),
            value: prefs.timeZoneMode == TimeZoneMode.device,
            onChanged: (on) => save(prefs.copyWith(
              timeZoneMode: on ? TimeZoneMode.device : TimeZoneMode.workspace,
            )),
          ),
        ],
      ),
    );
  }

  /// The format list as a sheet of rows with a check mark — #713 words,
  /// not tags: « Français (Suisse) · 1'234.56 ».
  Future<void> _pickLocale(
    BuildContext context,
    AppLocalizations? l10n,
    FormatPrefs prefs,
    Future<void> Function(FormatPrefs) save,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, controller) => ListView(
          controller: controller,
          children: [
            Padding(
              padding: AppSpacing.lgAll,
              child: Text(
                l10n?.regionalFormatLocale ?? 'Numbers & dates',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            _option(
              sheetContext,
              key: 'auto',
              label: l10n?.regionalFollowLanguage ?? 'Automatic',
              selected: prefs.formatLocale.isEmpty,
            ),
            for (final tag in kFormatLocales)
              _option(
                sheetContext,
                key: tag,
                label: formatLocaleLabel(l10n, tag),
                selected: prefs.formatLocale == tag,
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await save(prefs.copyWith(formatLocale: picked == 'auto' ? '' : picked));
  }

  Widget _option(
    BuildContext sheetContext, {
    required String key,
    required String label,
    required bool selected,
  }) =>
      ListTile(
        key: ValueKey('regional-locale-option-$key'),
        title: Text(label),
        trailing: selected
            ? Icon(Icons.check, color: Theme.of(sheetContext).colorScheme.primary)
            : null,
        selected: selected,
        onTap: () => Navigator.of(sheetContext).pop(key),
      );
}

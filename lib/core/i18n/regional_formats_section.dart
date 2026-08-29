// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/providers/profile_providers.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_spacing.dart';
import '../time/clock.dart';
import '../trace/guarded.dart';
import 'app_format.dart';
import 'format_controller.dart';
import 'format_prefs.dart';
import 'locale_names.dart';

/// Settings → Region & formats (#711): how THIS member reads numbers,
/// dates, the clock and the zone. Three controls and a live preview
/// line, because a format preference described in words ("Swiss
/// German") is a guess and one shown as `CHF 1'234.56 · 28.08.2026 ·
/// 14:30` is a choice.
class RegionalFormatsSection extends ConsumerWidget {
  const RegionalFormatsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final format = ref.watch(appFormatProvider);
    final now = ref.watch(clockProvider).now();
    // ONE tile in the Settings list — the preview IS the subtitle, so
    // the current choice reads without opening anything — and a sheet
    // for the three controls. Settings is a long list already; four
    // more rows pushed Status and Sign out below the fold.
    return ListTile(
      key: const ValueKey('regional-formats'),
      leading: const Icon(Icons.language_outlined),
      title: Text(l10n?.regionalFormatsTitle ?? 'Region & formats'),
      subtitle: Text(
        '${format.money(123456)} · ${format.date(now)} · ${format.time(now)}',
        key: const ValueKey('regional-preview'),
      ),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _RegionalFormatsSheet(),
      ),
    );
  }
}

class _RegionalFormatsSheet extends ConsumerWidget {
  const _RegionalFormatsSheet();

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

    return SafeArea(
      child: SingleChildScrollView(
      child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Text(
            l10n?.regionalFormatsTitle ?? 'Region & formats',
            style: theme.textTheme.titleMedium,
          ),
        ),
        // The preview: what the three choices below ADD UP to, on one
        // line, updated as they change.
        Padding(
          padding: AppSpacing.lgH,
          child: Text(
            '${format.money(123456)} · ${format.date(now)} · ${format.time(now)}',
            key: const ValueKey('regional-sheet-preview'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ListTile(
          key: const ValueKey('regional-locale'),
          leading: const Icon(Icons.language_outlined),
          title: Text(l10n?.regionalFormatLocale ?? 'Numbers & dates'),
          subtitle: Text(
            prefs.formatLocale.isEmpty
                ? (l10n?.regionalFormatLocaleAuto(
                        formatLocaleLabel(l10n, format.locale)) ??
                    'Follows the app language (${format.locale})')
                : formatLocaleLabel(l10n, prefs.formatLocale),
          ),
          trailing: DropdownButton<String>(
            value: prefs.formatLocale.isEmpty ? '' : prefs.formatLocale,
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(l10n?.regionalFollowLanguage ?? 'Automatic'),
              ),
              // #713 — words, not tags: « Français (Suisse) · 1'234.56 ».
              for (final tag in kFormatLocales)
                DropdownMenuItem(
                  value: tag,
                  child: Text(formatLocaleLabel(l10n, tag)),
                ),
            ],
            onChanged: (tag) =>
                save(prefs.copyWith(formatLocale: tag ?? '')),
          ),
        ),
        ListTile(
          key: const ValueKey('regional-clock'),
          leading: const Icon(Icons.schedule_outlined),
          title: Text(l10n?.regionalClock ?? 'Clock'),
          trailing: SegmentedButton<ClockPref>(
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
      ),
    );
  }
}

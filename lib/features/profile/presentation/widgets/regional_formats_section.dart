// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/i18n/format_prefs.dart';
import '../../../../core/i18n/locale_names.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/help_row.dart';
import '../../../../core/ui/kit/page_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/personal_preferences.dart';
import '../../providers/personal_preferences_providers.dart';
import '../../providers/profile_providers.dart';
import 'document_language_tile.dart';
import 'preference_scope_controls.dart';

/// Settings → Region & formats (#711): the member's own numbers, dates,
/// clock and time zone. The tile previews what the choices add up to;
/// the screen behind it edits them.
class RegionalFormatsSection extends ConsumerWidget {
  const RegionalFormatsSection({super.key, this.route = '/formats'});

  /// The screen behind the tile: a business's own formats ('/formats', behind
  /// its feature) or the person's own, from Me ('/me/formats', #3697).
  final String route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = ref.watch(appFormatProvider);
    final now = ref.watch(clockProvider).now();
    return ListTile(
      key: const ValueKey('regional-formats'),
      leading: const Icon(Icons.language_outlined),
      title: Text(l10n.regionalFormatsTitle),
      subtitle: Text(
        '${format.money(123456)} · ${format.date(now)} · ${format.time(now)}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
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
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scoped = ref.watch(workspacePreferenceEditingProvider);
    final stored = ref.watch(personalSettingsProvider).value;
    final defaults = ref.watch(myProfileProvider).value?.formatPrefs ?? FormatPrefs.defaults;
    final prefs = (scoped ? stored : PersonalPreferences(defaults: stored?.defaults ?? {}))
        ?.formats(defaults) ?? defaults;
    final format = ref.watch(appFormatProvider);
    final now = ref.watch(clockProvider).now();

    Future<void> save(FormatPrefs next) => runGuarded(
          context,
          domain: 'profile',
          message: 'save format prefs failed',
          errorText: l10n.workspaceGenericError,
          action: () async {
            if (scoped) {
              await ref.read(personalSettingsProvider.notifier).save({
                for (final entry in next.toDb().entries)
                  if (prefs.toDb()[entry.key] != entry.value) entry.key: entry.value as String,
              }, workspaceOnly: true);
            } else {
              await ref.read(myProfileEditsProvider).saveFormatPrefs(next);
              ref.invalidate(personalSettingsProvider);
            }
          },
        ).then((_) => ref.invalidate(myProfileProvider));

    final localeLabel = prefs.formatLocale.isEmpty
        ? (l10n.regionalFormatLocaleAuto(formatLocaleLabel(l10n, format.locale)))
        : formatLocaleLabel(l10n, prefs.formatLocale);

    return Scaffold(
      appBar: pageBar(context, title: l10n.regionalFormatsTitle),
      body: ListView(
        children: [
          const PreferenceScopeControls(),
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
          HelpRow(
            key: const ValueKey('regional-locale'),
            leading: const Icon(Icons.language_outlined),
            title: l10n.regionalFormatLocale,
 topic: l10n.helpTopicSettings,
 anchor: HelpAnchor.profileRegionalFormats,
            subtitle: Text(localeLabel),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickLocale(context, l10n, prefs, save),
          ),
          HelpRow(
            key: const ValueKey('regional-clock'),
            leading: const Icon(Icons.schedule_outlined),
            title: l10n.regionalClock,
 topic: l10n.helpTopicSettings,
 anchor: HelpAnchor.profileClock,
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
                  label: Text(l10n.regionalClockAuto),
                ),
                ButtonSegment(
                  value: ClockPref.h24,
                  label: Text(l10n.regionalClock24h),
                ),
                ButtonSegment(
                  value: ClockPref.h12,
                  label: Text(l10n.regionalClock12h),
                ),
              ],
              selected: {prefs.clock},
              onSelectionChanged: (s) => save(prefs.copyWith(clock: s.first)),
            ),
          ),
          HelpRow.toggle(
            key: const ValueKey('regional-device-zone'),
            leading: const Icon(Icons.public_outlined),
            title: l10n.regionalDeviceZone,
 topic: l10n.helpTopicSettings,
 anchor: HelpAnchor.profileDeviceZone,
            // Says what the default IS, because "workspace time" only
            // means something once you know the workspace is elsewhere.
            subtitle: Text(
              l10n.regionalDeviceZoneHint,
            ),
            value: prefs.timeZoneMode == TimeZoneMode.device,
            onChanged: (on) => save(prefs.copyWith(
              timeZoneMode: on ? TimeZoneMode.device : TimeZoneMode.workspace,
            )),
          ),
          // #3648 — the first day of the week, in every grid, strip and picker.
          HelpRow(
            key: const ValueKey('regional-week-start'),
            leading: const Icon(Icons.calendar_view_week_outlined),
            title: l10n.regionalWeekStart,
            subtitle: Text(_weekStartLabel(l10n, format, prefs.weekStart)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickWeekStart(context, l10n, format, prefs, save),
          ),
          // #3647 — its own preference, on the account: the interface
          // language no longer decides it once the person chose one.
          const DocumentLanguageTile(),
        ],
      ),
    );
  }

  /// "Monday" in the format locale, or the region-follows label.
  String _weekStartLabel(
    AppLocalizations l10n,
    AppFormat format,
    WeekStartPref pref,
  ) {
    final day = pref.isoWeekday;
    if (day == null) return l10n.regionalWeekStartAuto;
    // 2024-01-01 is a Monday: the day of month is the ISO weekday.
    return format.dates(DateShape.weekdayLong).format(DateTime(2024, 1, day));
  }

  Future<void> _pickWeekStart(
    BuildContext context,
    AppLocalizations l10n,
    AppFormat format,
    FormatPrefs prefs,
    Future<void> Function(FormatPrefs) save,
  ) async {
    final picked = await showAppSheet<WeekStartPref>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: AppSpacing.lgAll,
              child: Text(
                l10n.regionalWeekStart,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            for (final pref in WeekStartPref.values)
              ListTile(
                key: ValueKey('regional-week-start-option-${pref.wire}'),
                title: Text(_weekStartLabel(l10n, format, pref)),
                trailing: prefs.weekStart == pref
                    ? Icon(Icons.check,
                        color: Theme.of(sheetContext).colorScheme.primary)
                    : null,
                selected: prefs.weekStart == pref,
                onTap: () => Navigator.of(sheetContext).pop(pref),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await save(prefs.copyWith(weekStart: picked));
  }

  /// The format list as a sheet of rows with a check mark — #713 words,
  /// not tags: « Français (Suisse) · 1'234.56 ».
  Future<void> _pickLocale(
    BuildContext context,
    AppLocalizations l10n,
    FormatPrefs prefs,
    Future<void> Function(FormatPrefs) save,
  ) async {
    final picked = await showAppSheet<String>(
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
                l10n.regionalFormatLocale,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            _option(
              sheetContext,
              key: 'auto',
              label: l10n.vatTreatmentAuto,
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

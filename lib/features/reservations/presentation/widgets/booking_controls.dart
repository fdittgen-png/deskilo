// SPDX-License-Identifier: 0BSD
//
// The shared booking controls (space refactor): the Plan tab and the
// Reserve hub offer the same functions — pick a window, pick a level —
// but grew separate layouts. One implementation each, composed inline
// into a single compact header row by both screens.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../plan/domain/level.dart';
import '../../../workspace/domain/booking_granularity.dart';

/// Granularity-aware window picker, inline-compact: Morning/Afternoon/
/// Full-day chips under day-based rules (#201), from→to clock buttons on
/// minute grids (#184). Keys are `<keyPrefix>-am-chip` … so both screens
/// keep their pinned test keys.
class WindowControls extends StatelessWidget {
  const WindowControls({
    super.key,
    required this.keyPrefix,
    required this.granularity,
    required this.day,
    required this.isSelected,
    required this.onPickWindow,
    required this.from,
    required this.to,
    required this.onPickFrom,
    required this.onPickTo,
    this.muted = false,
  });

  /// 'plan' or 'reserve' — prefixes every control key.
  final String keyPrefix;
  final BookingGranularity granularity;

  /// The (workspace-local) day the half-day chips describe.
  final DateTime day;

  /// Whether [HalfDayWindow] is the currently selected window.
  final bool Function(HalfDayWindow window) isSelected;
  final ValueChanged<HalfDayWindow> onPickWindow;

  /// Displayed times of the flexible from→to buttons (local).
  final DateTime from;
  final DateTime to;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;

  /// De-emphasizes the from→to buttons (the Plan tab's live mode, where
  /// they only preview the window a tap would browse).
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (granularity.isDayBased) {
      // Icons, not words (UX pass): sunrise = morning, sunset =
      // afternoon, calendar-day = full day; the localized name lives in
      // the tooltip (and the semantics label for assistive tech).
      Widget chip(
        String keySuffix,
        IconData icon,
        String name,
        HalfDayWindow Function(DateTime day) windowOf,
      ) {
        final window = windowOf(day);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Tooltip(
            message: name,
            child: ChoiceChip(
              key: ValueKey('$keyPrefix-$keySuffix'),
              label: Icon(icon, size: 18, semanticLabel: name),
              selected: isSelected(window),
              materialTapTargetSize: MaterialTapTargetSize.padded,
              onSelected: (_) => onPickWindow(window),
            ),
          ),
        );
      }

      // A Wrap, not a Row: inside the portrait scroll-row it lays out
      // on one line (unbounded width); inside the landscape sidebar's
      // Wrap the chips flow instead of overflowing.
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Full-day granularity (0032) books whole days only — the
          // half chips exist under half-day granularity alone.
          if (granularity == BookingGranularity.halfDay) ...[
            chip(
              'am-chip',
              Icons.wb_sunny_outlined,
              l10n?.planMorningChip ?? 'Morning',
              HalfDayWindows.morning,
            ),
            chip(
              'pm-chip',
              Icons.wb_twilight,
              l10n?.planAfternoonChip ?? 'Afternoon',
              HalfDayWindows.afternoon,
            ),
          ],
          chip(
            'day-chip',
            Icons.today_outlined,
            l10n?.reserveFullDayChip ?? 'Full day',
            HalfDayWindows.fullDay,
          ),
        ],
      );
    }

    final timeFormat = DateFormat.Hm();
    final style = muted
        ? TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          )
        : null;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Tooltip(
          message: l10n?.planFromLabel ?? 'From',
          child: TextButton(
            key: ValueKey('$keyPrefix-from-chip'),
            style: style,
            onPressed: onPickFrom,
            child: Text(timeFormat.format(from)),
          ),
        ),
        Icon(
          Icons.arrow_right_alt,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        Tooltip(
          message: l10n?.planToLabel ?? 'To',
          child: TextButton(
            key: ValueKey('$keyPrefix-to-chip'),
            style: style,
            onPressed: onPickTo,
            child: Text(timeFormat.format(to)),
          ),
        ),
      ],
    );
  }
}

/// Floor switcher ON the plan (UX pass): a small vertical stack of
/// buttons floating over the canvas — where floors intuitively live
/// (the indoor-maps idiom) — instead of eating header space. One short
/// button per level (full name in the tooltip); beyond five levels it
/// collapses into a single menu button. [trailing] hosts contextual
/// per-level actions (the reserve-level icon).
class LevelSelector extends StatelessWidget {
  const LevelSelector({
    super.key,
    required this.keyPrefix,
    required this.levels,
    required this.current,
    required this.onSelected,
    this.trailing,
  });

  final String keyPrefix;
  final List<Level> levels;
  final Level current;
  final ValueChanged<String> onSelected;
  final Widget? trailing;

  /// A level's on-button short form: leading digits when the name has
  /// them ('2eme' → '2'), else its first two characters.
  static String shortLabel(String name) {
    final digits = RegExp(r'^\d+').firstMatch(name.trim())?.group(0);
    if (digits != null) return digits;
    final t = name.trim();
    return t.length <= 2 ? t : t.substring(0, 2);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (levels.length <= 5)
              for (final level in levels)
                Tooltip(
                  message: level.name,
                  child: InkWell(
                    key: ValueKey('$keyPrefix-level-${level.id}'),
                    borderRadius: AppRadius.smAll,
                    onTap: () => onSelected(level.id),
                    child: Container(
                      width: kMinInteractiveDimension,
                      height: kMinInteractiveDimension,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: level.id == current.id
                            ? scheme.secondaryContainer
                            : null,
                        borderRadius: AppRadius.smAll,
                      ),
                      child: Text(
                        shortLabel(level.name),
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(
                              fontWeight: level.id == current.id
                                  ? FontWeight.w700
                                  : null,
                            ),
                      ),
                    ),
                  ),
                )
            else
              PopupMenuButton<String>(
                key: ValueKey('$keyPrefix-level-menu'),
                tooltip: l10n?.planLevelTooltip ?? 'Level',
                onSelected: onSelected,
                icon: const Icon(Icons.layers_outlined),
                itemBuilder: (context) => [
                  for (final Level l in levels)
                    PopupMenuItem(
                      value: l.id,
                      child: Row(
                        children: [
                          Icon(
                            l.id == current.id ? Icons.check : null,
                            size: 18,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(l.name),
                        ],
                      ),
                    ),
                ],
              ),
            if (trailing != null) ...[
              const Divider(height: 1),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

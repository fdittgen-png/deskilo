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
      Widget chip(
        String keySuffix,
        String label,
        HalfDayWindow Function(DateTime day) windowOf,
      ) {
        final window = windowOf(day);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: ChoiceChip(
            key: ValueKey('$keyPrefix-$keySuffix'),
            label: Text(label),
            selected: isSelected(window),
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: (_) => onPickWindow(window),
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
              l10n?.planMorningChip ?? 'Morning',
              HalfDayWindows.morning,
            ),
            chip(
              'pm-chip',
              l10n?.planAfternoonChip ?? 'Afternoon',
              HalfDayWindows.afternoon,
            ),
          ],
          chip(
            'day-chip',
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

/// Compact level picker (#283): a chip-styled button naming the current
/// level; the menu lists all levels. One tap to switch regardless of
/// level count — replaces whole rows of level chips in headers.
class LevelMenuButton extends StatelessWidget {
  const LevelMenuButton({
    super.key,
    required this.levels,
    required this.current,
    required this.onSelected,
  });

  final List<Level> levels;
  final Level current;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: l10n?.planLevelTooltip ?? 'Level',
      onSelected: onSelected,
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
      child: Container(
        constraints: BoxConstraints(
          minHeight: kMinInteractiveDimension,
          maxWidth: MediaQuery.sizeOf(context).width * 0.4,
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: AppRadius.xlAll,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                current.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

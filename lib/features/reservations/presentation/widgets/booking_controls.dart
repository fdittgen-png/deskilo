// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The shared booking controls (space refactor): the Plan tab and the
// Reserve hub offer the same functions — pick a window, pick a level —
// but grew separate layouts. One implementation each, composed inline
// into a single compact header row by both screens.
import 'package:flutter/material.dart';
import '../../../../core/l10n/lexicon.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../plan/domain/level.dart';
import '../../../workspace/domain/booking_granularity.dart';
import '../../../../core/i18n/format_controller.dart';

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
    final timeFormat = appFormatOf(context); // #1150
    // Icons, not words (UX pass): the localized name lives in the
    // tooltip (and the semantics label for assistive tech).
    //
    // #1269 — "the morning and afternoon selection could be more
    // meaningful". It was a sunrise, a sunset and a calendar page: three
    // unrelated glyphs at 18dp, none of which said WHICH hours it books
    // or that the three are one family. Two changes, both free in
    // width — and width is why these are icons at all (#699):
    //
    //   * the glyph is now the week grid's own day cell, two half-slots
    //     side by side with the booked half filled. A member who has
    //     seen the week view has already learnt to read it, and the
    //     three chips finally look like three parts of one choice.
    //   * the tooltip and the semantics label carry the real hours —
    //     "Morning · 08:00–13:00" — off the workspace's configured
    //     working day, so "morning" stops being a guess. Hours in the
    //     chip itself would cost ~62dp and take the hub's header to a
    //     third row at 360dp, which is the trade #699 already refused.
    Widget chip(
      String keySuffix,
      ({bool am, bool pm}) halves,
      String name,
      HalfDayWindow Function(DateTime day) windowOf,
    ) {
      final window = windowOf(day);
      final label = '$name · ${timeFormat.time(window.start)}'
          '–${timeFormat.time(window.end)}';
      return Tooltip(
        message: label,
        child: ChoiceChip(
          key: ValueKey('$keyPrefix-$keySuffix'),
          label: DayHalvesGlyph(
            am: halves.am,
            pm: halves.pm,
            semanticLabel: label,
          ),
          selected: isSelected(window),
          materialTapTargetSize: MaterialTapTargetSize.padded,
          // #699 — SQUARE, 48dp, not the default chip's ~58dp text box.
          // An icon-only chip carries Material's label padding for a
          // label it does not have; three of them cost 42dp of header
          // width, which is the difference between the hub's controls
          // taking two rows and taking three. The 48 is the tap target
          // itself, so this shrinks the padding, never the target.
          labelPadding: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          // No checkmark: it is drawn INSIDE the chip, beside an icon
          // that is already the label, so a selected chip grew by 18dp
          // and read as two symbols meaning one thing. The fill says
          // selected on its own.
          showCheckmark: false,
          onSelected: (_) => onPickWindow(window),
        ),
      );
    }

    final style = muted
        ? TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          )
        : null;
    // A Wrap, not a Row: inside the portrait scroll-row it lays out
    // on one line (unbounded width); inside the landscape sidebar's
    // Wrap the chips flow instead of overflowing. Under `hours` (#446)
    // BOTH families render: the window chips as shortcuts next to the
    // free from→to clock buttons.
    return Wrap(
      // Tight, because these chips are ONE group: 2dp reads as a
      // segmented control, the header's spacing between separate
      // controls stays at 4.
      spacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (granularity.offersDayWindows) ...[
          // Full-day granularity (0032) books whole days only — the
          // half chips exist under half-day and hours granularity.
          if (granularity != BookingGranularity.fullDay) ...[
            chip(
              'am-chip',
              (am: true, pm: false),
              lexiconText(context, key: 'planMorningChip', fallback: l10n?.planMorningChip ?? 'Morning'),
              HalfDayWindows.morning,
            ),
            chip(
              'pm-chip',
              (am: false, pm: true),
              lexiconText(context, key: 'planAfternoonChip', fallback: l10n?.planAfternoonChip ?? 'Afternoon'),
              HalfDayWindows.afternoon,
            ),
          ],
          chip(
            'day-chip',
            (am: true, pm: true),
            lexiconText(context, key: 'reserveFullDayChip', fallback: l10n?.reserveFullDayChip ?? 'Full day'),
            HalfDayWindows.fullDay,
          ),
        ],
        if (!granularity.isDayBased) ...[
          Tooltip(
            message: lexiconText(context, key: 'planFromLabel', fallback: l10n?.planFromLabel ?? 'From'),
            child: TextButton(
              key: ValueKey('$keyPrefix-from-chip'),
              style: style,
              onPressed: onPickFrom,
              child: Text(timeFormat.time(from)),
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
              child: Text(timeFormat.time(to)),
            ),
          ),
        ],
      ],
    );
  }
}

/// One row of the Reserve hub's header (#699).
///
/// THE HEADER IS TWO ROWS, and the split means something: row one is
/// WHAT you are looking at (the four views, map-or-list), row two is
/// WHEN — the date, the way back to now, the window chips. One Wrap
/// holding all of them flowed onto THREE lines at phone width, which is
/// a lot of chrome above a screen whose job is the canvas below it.
///
/// A Wrap, never a scroll: every control stays visible at any width, and
/// at a large text scale a row flows rather than overflows. Fitting the
/// two rows at the default scale took the width back from the padding —
/// hence [AppSpacing.sm] insets rather than the screen gutter, which is
/// what lets row two hold date + now + chips at 360dp in German, the
/// widest of the five languages.
class HeaderControlRow extends StatelessWidget {
  const HeaderControlRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          bottom: AppSpacing.xs,
        ),
        child: Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        ),
      );
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
                              // secondaryContainer stays LIGHT in the
                              // dark theme — the pill must carry its
                              // on-color (contrast, field report).
                              color: level.id == current.id
                                  ? scheme.onSecondaryContainer
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

/// #1269 — the week grid's day cell, at chip size: two half-slots side
/// by side, the booked half filled and the other left as an outline.
///
/// The same shape the week view paints (`WeekGridMetrics.halfSlotGap`),
/// so morning / afternoon / full day are read the way the grid already
/// taught them, rather than as a sunrise and a sunset that happen to sit
/// next to each other. It takes the chip's own foreground colour, so a
/// selected chip's glyph follows it without being told.
class DayHalvesGlyph extends StatelessWidget {
  const DayHalvesGlyph({
    super.key,
    required this.am,
    required this.pm,
    this.semanticLabel,
  });

  /// Whether the morning half is filled.
  final bool am;

  /// Whether the afternoon half is filled.
  final bool pm;

  final String? semanticLabel;

  /// Total width, matching the 18dp icon these chips used to carry.
  static const double _width = 18;
  static const double _height = 14;
  static const double _gap = 2;

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurfaceVariant;
    Widget half(bool filled) => Container(
          width: (_width - _gap) / 2,
          height: _height,
          decoration: BoxDecoration(
            color: filled ? color : Colors.transparent,
            border: filled ? null : Border.all(color: color, width: 1.2),
            borderRadius: AppRadius.smAll,
          ),
        );
    return Semantics(
      label: semanticLabel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          half(am),
          const SizedBox(width: _gap),
          half(pm),
        ],
      ),
    );
  }
}

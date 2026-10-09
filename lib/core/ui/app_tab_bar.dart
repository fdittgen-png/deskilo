// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2313 — the app's ONE horizontal menu.
//
// Five tab bars and two section-link rows each had their own look: an
// underline here, filled tabs there, pills in Money, wrapped text links
// in Settings and Workspace. Every horizontal menu is now a row of the
// same pills (the selected one filled), 48 dp to the finger, and it
// behaves the same way at every width:
//
//   * [AppTabBar] — tabs of a screen. Labels that fit the width share it
//     evenly; when they do not (a phone, large text), the row scrolls
//     sideways instead of squeezing or wrapping the words;
//   * [SectionJumpBar] — the sections of one long form, each pill opening
//     and scrolling to its section. On a phone it is ONE row: the pills
//     that fit, and the rest behind a "more" button. Wider, every pill is
//     shown and they flow onto a second row if they must. It never
//     scrolls sideways, so a form keeps a single scrollable.
import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// The pill look shared by every horizontal menu.
abstract final class AppTabStyle {
  /// The finger's height of one pill.
  static const double height = 48;

  /// Inside one pill, left and right of its words.
  static const EdgeInsets labelPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
  );

  /// Below this width the menus take their phone form.
  static const double phoneWidth = 600;

  static TextStyle label(BuildContext context) =>
      (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w600,
      );

  /// The width one pill needs for [text], padding included.
  static double pillWidth(BuildContext context, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: label(context)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.width + labelPadding.horizontal;
  }

  /// Whether pills for [labels] fit side by side in [width].
  static bool fits(BuildContext context, List<String> labels, double width) {
    var total = 0.0;
    for (final text in labels) {
      total += pillWidth(context, text);
    }
    return total <= width;
  }
}

/// One tab of an [AppTabBar].
class AppTab {
  const AppTab(this.label, {this.key, this.badge = 0});
  final String label;
  final Key? key;

  /// A count shown beside the label (0: none).
  final int badge;
}

/// What a badge adds to a pill's width.
const double _badgeWidth = 28;

/// The tabs of a screen, in the app's pill style.
///
/// Usable as an `AppBar.bottom` (it is a [PreferredSizeWidget]) or in a
/// body above a `TabBarView`.
class AppTabBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTabBar({
    required this.tabs,
    this.controller,
    this.onTap,
    this.barKey,
    super.key,
  });

  final List<AppTab> tabs;
  final TabController? controller;
  final ValueChanged<int>? onTap;

  /// The key of the inner [TabBar] (kept from the bars this replaced).
  final Key? barKey;

  static const double _inset = AppSpacing.sm;

  /// Below the tabs: the bar's own 2 px indicator weight and the inset.
  static const double _chrome = 2 + _inset;

  @override
  Size get preferredSize => const Size.fromHeight(AppTabStyle.height + _chrome);

  /// A tab's height here: two or three fixed tabs make room for two lines
  /// of large text.
  static double tabHeight(BuildContext context, int count) => count <= 3
      ? MediaQuery.textScalerOf(context)
            .scale(AppTabStyle.height)
            .clamp(AppTabStyle.height, 96)
      : AppTabStyle.height;

  /// An [AppTabBar] as an `AppBar.bottom`, sized for the reader's text
  /// size (a [PreferredSizeWidget] cannot read it on its own).
  static PreferredSizeWidget bottom(
    BuildContext context, {
    required List<AppTab> tabs,
    TabController? controller,
    Key? barKey,
  }) => PreferredSize(
    preferredSize: Size.fromHeight(tabHeight(context, tabs.length) + _chrome),
    child: AppTabBar(tabs: tabs, controller: controller, barKey: barKey),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = AppTabStyle.label(context);
    return LayoutBuilder(
      builder: (context, box) {
        // Filled, every tab gets an equal share: the WIDEST label decides.
        var widest = 0.0;
        for (final t in tabs) {
          final width =
              AppTabStyle.pillWidth(context, t.label) +
              (t.badge > 0 ? _badgeWidth : 0);
          if (width > widest) widest = width;
        }
        // Two or three tabs always share the width (Material's fixed
        // tabs): every choice stays in view, a long label takes two
        // lines. From four, a row that does not fit scrolls sideways.
        final fixed = tabs.length <= 3;
        final fit = fixed || widest * tabs.length <= box.maxWidth - 2 * _inset;
        return Padding(
          padding: const EdgeInsets.fromLTRB(_inset, 0, _inset, _inset),
          child: TabBar(
            key: barKey,
            controller: controller,
            onTap: onTap,
            isScrollable: !fit,
            tabAlignment: fit ? TabAlignment.fill : TabAlignment.start,
            indicator: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: AppRadius.xxlAll,
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xs,
            ),
            dividerColor: Colors.transparent,
            labelColor: scheme.onSecondaryContainer,
            unselectedLabelColor: scheme.onSurfaceVariant,
            labelStyle: style,
            unselectedLabelStyle: style.copyWith(fontWeight: FontWeight.w500),
            labelPadding: AppTabStyle.labelPadding,
            splashBorderRadius: AppRadius.xxlAll,
            tabs: [
              for (final t in tabs)
                Tab(
                  key: t.key,
                  // Two lines of a fixed tab need the room of two lines.
                  height: tabHeight(context, tabs.length),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          t.label,
                          maxLines: fixed ? 2 : 1,
                          softWrap: fixed,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (t.badge > 0) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Badge.count(count: t.badge),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One entry of a [SectionJumpBar].
class SectionJump {
  const SectionJump({
    required this.key,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  /// The pill's widget key (kept from the links it replaces).
  final String key;
  final String label;
  final VoidCallback onPressed;

  /// The danger zone: drawn in the error colour.
  final bool destructive;
}

/// The sections of one long form, in the app's pill style.
class SectionJumpBar extends StatefulWidget {
  const SectionJumpBar({required this.items, super.key});

  final List<SectionJump> items;

  @override
  State<SectionJumpBar> createState() => _SectionJumpBarState();
}

class _SectionJumpBarState extends State<SectionJumpBar> {
  /// The section last opened from the bar: drawn selected.
  String? _current;

  void _open(SectionJump item) {
    setState(() => _current = item.key);
    item.onPressed();
  }

  Widget _pill(BuildContext context, SectionJump item) {
    final scheme = Theme.of(context).colorScheme;
    final selected = item.key == _current;
    final ink = item.destructive
        ? scheme.error
        : selected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    return TextButton(
      key: ValueKey(item.key),
      onPressed: () => _open(item),
      style: TextButton.styleFrom(
        shape: const StadiumBorder(),
        backgroundColor: selected ? scheme.secondaryContainer : null,
        foregroundColor: ink,
        padding: AppTabStyle.labelPadding,
        minimumSize: const Size(0, 40),
        textStyle: AppTabStyle.label(context)
            .copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
      ),
      child: Text(item.label, maxLines: 1, softWrap: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          // Wide: every pill, flowing onto a second row if it must.
          if (box.maxWidth >= AppTabStyle.phoneWidth) {
            return Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [for (final item in items) _pill(context, item)],
            );
          }
          // Phone: one row — the pills that fit, the rest behind "more".
          const more = AppTabStyle.height;
          var used = 0.0;
          var shown = 0;
          for (final item in items) {
            final width =
                AppTabStyle.pillWidth(context, item.label) + AppSpacing.xs;
            final reserve = shown == items.length - 1 ? 0.0 : more;
            if (used + width + reserve > box.maxWidth) break;
            used += width;
            shown++;
          }
          final rest = items.skip(shown).toList();
          return Row(
            children: [
              for (final item in items.take(shown))
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: _pill(context, item),
                ),
              if (rest.isNotEmpty)
                PopupMenuButton<SectionJump>(
                  key: const ValueKey('section-jump-more'),
                  tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
                  icon: const Icon(Icons.more_horiz),
                  style: IconButton.styleFrom(shape: const CircleBorder()),
                  onSelected: _open,
                  itemBuilder: (context) => [
                    for (final item in rest)
                      PopupMenuItem(
                        key: ValueKey(item.key),
                        value: item,
                        child: Text(
                          item.label,
                          style: item.destructive
                              ? TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

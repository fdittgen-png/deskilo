// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4492 — a page's other actions, behind one worded button in its bar: the
// word "More", never an unnamed icon, and every line a sentence a person
// reads (sheets A1 and B1 of docs/design/ux-2026-11). The page's one main
// action stays outside it ([pageBarAction] or the bottom bar); a line that
// has no action heads the lines after it. On a phone (compact width) the
// word gives way to the ⋮ named "More": the page's main action keeps its
// words, and the bar holds both at 320 dp and in every language.
import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../adaptive/window_class.dart';

/// The face of a page's More button: the word and its arrow, or on a phone
/// the ⋮ (its name is the menu's tooltip).
Widget pageMoreFace(BuildContext context) {
  if (WindowClass.of(context) == WindowClass.compact) {
    return const SizedBox.square(
      dimension: 48,
      child: Icon(Icons.more_vert),
    );
  }
  return ConstrainedBox(
    // The worded button is a whole target, not just its words.
    constraints: const BoxConstraints(minHeight: 48),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(MaterialLocalizations.of(context).moreButtonTooltip),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    ),
  );
}

/// One line of a page's More menu.
@immutable
class PageMoreEntry {
  const PageMoreEntry({
    required this.key,
    required this.label,
    required this.onSelected,
  });

  /// A heading over the lines after it: it does nothing.
  const PageMoreEntry.heading({required this.key, required this.label})
    : onSelected = null;

  /// The line's own key, so a test and the recorder press what a person
  /// presses.
  final ValueKey<String> key;
  final String label;

  /// What the line does; null for a heading.
  final VoidCallback? onSelected;
}

/// The worded More button of a page's bar and its menu. With no line that
/// does something it draws nothing: a menu that opens on headings alone
/// offers nothing.
class PageMoreMenu extends StatelessWidget {
  const PageMoreMenu({super.key, required this.entries, this.enabled = true});

  final List<PageMoreEntry> entries;

  /// False while the page runs an action: the menu waits for it.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (entries.every((e) => e.onSelected == null)) {
      return const SizedBox.shrink();
    }
    final word = MaterialLocalizations.of(context).moreButtonTooltip;
    return PopupMenuButton<String>(
      tooltip: word,
      enabled: enabled,
      // By the line's key, read from the lines as they are now: a page that
      // was rebuilt while the menu stood open never runs a neighbour's action.
      onSelected: (id) {
        for (final e in entries) {
          if (e.key.value == id) {
            e.onSelected?.call();
            return;
          }
        }
      },
      itemBuilder: (context) => [
        for (final e in entries)
          if (e.onSelected == null)
            PopupMenuItem<String>(
              key: e.key,
              enabled: false,
              height: 32,
              child: Text(
                e.label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            )
          else
            PopupMenuItem<String>(
              key: e.key,
              value: e.key.value,
              child: Text(e.label),
            ),
      ],
      child: pageMoreFace(context),
    );
  }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-a -- a single-choice filter as chips that wrap onto a second line,
// never a sideways scroller.
import 'package:flutter/material.dart';

/// One chip: its value, its words and its key.
typedef FilterOption<T> = ({T value, String label, Key key});

class FilterChips<T> extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<FilterOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final o in options)
        ChoiceChip(
          key: o.key,
          label: Text(o.label),
          selected: o.value == selected,
          showCheckmark: false,
          onSelected: (_) => onSelected(o.value),
        ),
    ],
  );
}

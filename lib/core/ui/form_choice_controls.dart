// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3608 B1 -- the choice controls of a form, as the kit has them: a switch row and a row of choice chips. A raw `Switch` or
// `ChoiceChip` in a task's body changes a value without the task knowing it was changed (a swipe or a back press would then
// drop the change unasked); these two tell the task, so a form uses them instead.
import 'package:flutter/material.dart';

import 'adaptive/task_surface.dart';

/// One choice of [AppChoiceChips]: the value it stands for, its words and the key a test finds it by.
class AppChoice<T> {
  const AppChoice({required this.value, required this.label, required this.key});

  final T value;
  final String label;
  final Key key;
}

/// A row of single-choice chips: the chosen one is selected; a tap names the choice and tells the task it changed.
class AppChoiceChips<T> extends StatelessWidget {
  const AppChoiceChips({super.key, required this.choices, required this.selected, required this.onSelected});

  final List<AppChoice<T>> choices;
  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      for (final c in choices)
        ChoiceChip(
          key: c.key,
          label: Text(c.label),
          selected: selected == c.value,
          onSelected: (_) {
            TaskSession.maybeOf(context)?.markChanged();
            onSelected(c.value);
          },
        ),
    ],
  );
}

/// A row with a title and a switch: a change names the new value and tells the task it changed.
class AppSwitchRow extends StatelessWidget {
  const AppSwitchRow({super.key, required this.title, required this.value, required this.onChanged});

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    value: value,
    onChanged: (v) {
      TaskSession.maybeOf(context)?.markChanged();
      onChanged(v);
    },
  );
}

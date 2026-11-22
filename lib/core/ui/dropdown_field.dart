// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4178 -- one choice out of a list inside a form: a labelled dropdown with its
// problem under it, the kit's own control for it. A task body picks a value
// through this and never builds the raw platform control itself.
import 'package:flutter/material.dart';

/// One value of [T] chosen from [items], with a [hint] while none is and an
/// [error] under the field.
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.items,
    required this.onChanged,
    this.value,
    this.hint,
    this.error,
  });

  final String label;
  final T? value;
  final String? hint;
  final String? error;

  /// The choices, each as its value and the text shown for it.
  final List<(T, String)> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    isExpanded: true,
    initialValue: value,
    decoration: InputDecoration(labelText: label, errorText: error),
    hint: hint == null ? null : Text(hint!),
    items: [
      for (final (v, text) in items)
        DropdownMenuItem<T>(value: v, child: Text(text, overflow: TextOverflow.ellipsis)),
    ],
    onChanged: onChanged,
  );
}

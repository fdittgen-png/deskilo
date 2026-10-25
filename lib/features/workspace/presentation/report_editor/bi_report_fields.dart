// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The small controls of the report editor: a text field that follows its
// value (an Undo changes what it shows, typing changes the value), a choice
// row and a stepper with labelled buttons — each reachable by keyboard and
// named for a screen reader.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/form_kit.dart';

/// An [AppTextField] showing [value]; [onChanged] reports what is typed. A
/// new [value] from elsewhere (Undo) replaces the text unless the field is
/// being typed in.
class BiSyncedField extends StatefulWidget {
  const BiSyncedField({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.maxLength,
    this.maxLines = 1,
  });

  final String value;
  final String label;
  final ValueChanged<String> onChanged;
  final int? maxLength;
  final int maxLines;

  @override
  State<BiSyncedField> createState() => _BiSyncedFieldState();
}

class _BiSyncedFieldState extends State<BiSyncedField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.value,
  );
  final _focus = FocusNode();

  @override
  void didUpdateWidget(BiSyncedField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _text.text != widget.value) {
      _text.text = widget.value;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _focus,
    skipTraversal: true,
    child: AppTextField(
      key: ValueKey('${(widget.key as ValueKey<String>?)?.value}-input'),
      controller: _text,
      label: widget.label,
      maxLength: widget.maxLength,
      maxLines: widget.maxLines,
      onChanged: widget.onChanged,
    ),
  );
}

/// A labelled dropdown of [choices]; choosing one reports it, even one the
/// figure cannot keep — the editor then says why and keeps the old choice.
class BiChoiceField<T> extends StatelessWidget {
  const BiChoiceField({
    super.key,
    required this.label,
    required this.value,
    required this.choices,
    required this.name,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> choices;
  final String Function(T) name;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: DropdownButtonFormField<T>(
      // A value changed elsewhere (Undo) rebuilds the field with it.
      key: ValueKey('${(key as ValueKey<String>?)?.value}-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final c in choices)
          DropdownMenuItem(value: c, child: Text(name(c))),
      ],
      onChanged: (v) {
        if (v != null || null is T) onChanged(v as T);
      },
    ),
  );
}

/// "[label]: [value]" with a decrease and an increase button.
class BiStepper extends StatelessWidget {
  const BiStepper({
    super.key,
    required this.keyPrefix,
    required this.label,
    required this.value,
    required this.less,
    required this.more,
    required this.onLess,
    required this.onMore,
  });

  /// The buttons are `<keyPrefix>-less` and `<keyPrefix>-more`.
  final String keyPrefix;
  final String label;
  final String value;

  /// The buttons' names, for the screen reader and the tooltip.
  final String less;
  final String more;
  final VoidCallback? onLess;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text('$label: $value')),
      IconButton(
        key: ValueKey('$keyPrefix-less'),
        tooltip: less,
        icon: const Icon(Icons.remove),
        onPressed: onLess,
      ),
      IconButton(
        key: ValueKey('$keyPrefix-more'),
        tooltip: more,
        icon: const Icon(Icons.add),
        onPressed: onMore,
      ),
    ],
  );
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3946 — one choice of a radio group, as a row: ONE focus stop per choice.
// Material's RadioListTile is two stops (the row, then the radio inside it),
// so Tab visits every choice twice, and the radio inside has no name of its
// own. Here the row is the radio: Tab reaches the group's choices, the
// arrows (RadioGroup's) move between them and select, Space selects, the
// whole row is the target, and the row's name, its hint and its checked
// state are ONE semantics node.
import 'package:flutter/material.dart';

/// A choice of the [RadioGroup] above it.
class RadioRow<T> extends StatefulWidget {
  const RadioRow({
    required this.value,
    required this.title,
    this.subtitle,
    this.enabled = true,
    super.key,
  });

  final T value;
  final Widget title;
  final Widget? subtitle;
  final bool enabled;

  @override
  State<RadioRow<T>> createState() => _RadioRowState<T>();
}

class _RadioRowState<T> extends State<RadioRow<T>> {
  final _focus = FocusNode(debugLabel: 'RadioRow');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final title = widget.title;
    final subtitle = widget.subtitle;
    final enabled = widget.enabled;
    final registry = RadioGroup.maybeOf<T>(context);
    assert(registry != null, 'a RadioRow belongs in a RadioGroup<$T>');
    final theme = Theme.of(context);
    return MergeSemantics(
      child: RawRadio<T>(
        value: value,
        mouseCursor: WidgetStateMouseCursor.clickable,
        toggleable: false,
        focusNode: _focus,
        autofocus: false,
        groupRegistry: registry,
        enabled: enabled && registry != null,
        builder: (context, state) {
          final selected = state.value ?? false;
          // The group is one Tab stop, as on the platform: its chosen row
          // (all of them while none is chosen). The arrows reach the rest.
          _focus.skipTraversal = !selected && registry?.groupValue != null;
          final focused = state.states.contains(WidgetState.focused);
          final hovered = state.states.contains(WidgetState.hovered);
          final scheme = theme.colorScheme;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: hovered
                  ? scheme.onSurface.withValues(alpha: 0.08)
                  : focused
                  ? scheme.onSurface.withValues(alpha: 0.12)
                  : null,
              border: focused
                  ? Border.all(color: scheme.primary, width: 2)
                  : null,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: kMinInteractiveDimension,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: !enabled
                          ? theme.disabledColor
                          : selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DefaultTextStyle.merge(
                            style: theme.textTheme.bodyLarge,
                            child: title,
                          ),
                          if (subtitle != null)
                            DefaultTextStyle.merge(
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                              child: subtitle,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

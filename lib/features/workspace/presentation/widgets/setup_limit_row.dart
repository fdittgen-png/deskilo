// SPDX-License-Identifier: AGPL-3.0-or-later
//
// One number a setup page lets the owner pick: its title and what it means
// above the control, so a phone gives the words the whole width instead of
// squeezing them beside a dropdown.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

class SetupLimitRow extends StatelessWidget {
  const SetupLimitRow({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.control,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(description, style: theme.textTheme.bodySmall),
          control,
        ],
      ),
    );
  }
}

/// A dropdown of sensible values. A value stored outside [options] (written
/// by hand, or a bound this build does not offer) joins its own copy of the
/// list, so the dropdown shows it instead of asserting.
class SetupLimitDropdown extends StatelessWidget {
  const SetupLimitDropdown({
    super.key,
    required this.dropdownKey,
    required this.value,
    required this.options,
    required this.format,
    required this.onChanged,
  });

  /// The dropdown's own key, the name a recording gives a tap on it.
  final String dropdownKey;
  final int value;
  final List<int> options;
  final String Function(int) format;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = options.contains(value)
        ? options
        : (<int>[...options, value]..sort());
    return DropdownButton<int>(
      key: ValueKey(dropdownKey),
      value: value,
      items: [
        for (final option in items)
          DropdownMenuItem(value: option, child: Text(format(option))),
      ],
      onChanged: (v) {
        if (v != null && v != value) onChanged(v);
      },
    );
  }
}

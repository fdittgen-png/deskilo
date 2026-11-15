// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545, #3674 -- a search field that reads as a place to start: the surface
// colour with no border, a quiet hint and icon, never a disabled box.
import 'package:flutter/material.dart';

import '../../theme/personal_theme.dart';

/// [child] (a text field) wearing the filled look.
class FilledField extends StatelessWidget {
  const FilledField({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const none = OutlineInputBorder(
      borderRadius: PersonalShellMetrics.controlRadiusAll,
      borderSide: BorderSide.none,
    );
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: scheme.surface,
          border: none,
          enabledBorder: none,
          focusedBorder: none,
          hintStyle: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          prefixIconColor: scheme.onSurfaceVariant,
          suffixIconColor: scheme.onSurfaceVariant,
        ),
      ),
      child: child,
    );
  }
}

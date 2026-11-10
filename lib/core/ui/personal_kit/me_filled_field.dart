// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 -- the search field of Me: a surface-coloured field with no border, a
// quiet hint and icon, so it reads as a place to start, not a disabled box.
import 'package:flutter/material.dart';

import '../../theme/personal_theme.dart';

/// [child] (a text field) wearing the Me field look.
class MeFilledField extends StatelessWidget {
  const MeFilledField({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = PersonalTheme.of(context);
    const none = OutlineInputBorder(
      borderRadius: PersonalShellMetrics.controlRadiusAll,
      borderSide: BorderSide.none,
    );
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: tokens.surface,
          border: none,
          enabledBorder: none,
          focusedBorder: none,
          hintStyle: theme.textTheme.bodyLarge?.copyWith(
            color: tokens.secondaryText,
          ),
          prefixIconColor: tokens.secondaryText,
          suffixIconColor: tokens.secondaryText,
        ),
      ),
      child: child,
    );
  }
}

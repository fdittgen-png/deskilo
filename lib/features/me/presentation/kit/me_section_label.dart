// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step 0 -- the small upper-case label at the top of a card.
import 'package:flutter/material.dart';

import '../../../../core/theme/personal_theme.dart';

class MeSectionLabel extends StatelessWidget {
  const MeSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = PersonalTheme.of(context);
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: tokens.secondaryText,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step 0 -- the card of Me: `surface` on the canvas, a decorative
// border, no shadow; [MeCardTone.hero] is `primary` with `onPrimary` text.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/personal_theme.dart';
import 'me_kit_metrics.dart';

/// How a card looks.
enum MeCardTone { normal, hero }

class MeCard extends StatelessWidget {
  const MeCard({
    super.key,
    required this.child,
    this.tone = MeCardTone.normal,
    this.padding = const EdgeInsets.all(MeKitMetrics.cardPadding),
  });

  final Widget child;
  final MeCardTone tone;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tokens = PersonalTheme.of(context);
    final hero = tone == MeCardTone.hero;
    final foreground = hero ? tokens.onPrimary : tokens.text;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: hero ? tokens.primary : tokens.surface,
        borderRadius: AppRadius.xlAll,
        border: hero ? null : Border.all(color: tokens.decorativeBorder),
      ),
      child: Padding(
        padding: padding,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: foreground),
          child: IconTheme.merge(
            data: IconThemeData(color: foreground),
            child: child,
          ),
        ),
      ),
    );
  }
}

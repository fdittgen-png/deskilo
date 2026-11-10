// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step 0 -- the one-line empty state: a check icon and a sentence. An
// empty section shrinks to this; it never takes a block.
import 'package:flutter/material.dart';

import '../../../../core/theme/personal_theme.dart';
import 'me_kit_metrics.dart';

class MeQuietLine extends StatelessWidget {
  const MeQuietLine(this.text, {super.key, this.icon = Icons.check_circle_outline});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = PersonalTheme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: MeKitMetrics.minTarget),
      child: Row(
        children: [
          Icon(icon, size: 20, color: tokens.success),
          const SizedBox(width: MeKitMetrics.gap),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: tokens.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

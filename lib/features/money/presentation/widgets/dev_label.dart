// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../l10n/app_localizations.dart';

/// A development space's name with DEV beside it, in the development
/// colour: test data must never read as production in Me.
class DevLabel extends StatelessWidget {
  const DevLabel({super.key, required this.name, this.small = false});
  final String name;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tone = AppEnvironmentColors.developmentOf(theme.brightness);
    final style = (small ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
        ?.copyWith(color: tone);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          key: const ValueKey('dev-label-chip'),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            border: Border.all(color: tone.withValues(alpha: .6)),
            borderRadius: AppRadius.smAll,
          ),
          child: Text(
            l10n?.profilesPairDev ?? 'DEV',
            style: theme.textTheme.labelSmall?.strong.copyWith(color: tone),
          ),
        ),
      ],
    );
  }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../l10n/app_localizations.dart';

/// A workspace name followed by PROD / DEV, in the colours of the Start page:
/// green filled says the space is real, orange outlined one to try things in.
/// Two spaces of one pair carry the same name, so the word is what tells them
/// apart.
class EnvironmentLabel extends StatelessWidget {
  const EnvironmentLabel(this.name, this.isProd, {super.key});
  final String name;
  final bool isProd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final fill = isProd
        ? AppEnvironmentColors.productionOf(brightness)
        : AppEnvironmentColors.developmentOf(brightness);
    return Row(
      children: [
        Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Container(
          key: ValueKey(isProd ? 'env-pill-prod' : 'env-pill-dev'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isProd ? fill : Colors.transparent,
            borderRadius: AppRadius.lgAll,
            border: isProd
                ? null
                : Border.all(color: fill.withValues(alpha: .4)),
          ),
          child: Text(
            isProd
                ? (l10n?.profilesPairProd ?? 'PROD')
                : (l10n?.profilesPairDev ?? 'DEV'),
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(
                  color: isProd
                      ? AppStatusColors.onSuccessOf(brightness)
                      : fill,
                )
                .strong,
          ),
        ),
      ],
    );
  }
}

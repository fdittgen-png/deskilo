// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ADR 0035 — what personally concerns a member (invoices, reminders,
// payments) is gathered in Me › Finances, from every workspace. A workspace's
// own money screens point there instead of repeating it: one tap, already
// narrowed to this space.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../my_finances_route.dart';

class MyFinancesLinkCard extends StatelessWidget {
  const MyFinancesLinkCard({
    super.key,
    required this.workspaceId,
    required this.workspaceName,
  });

  /// The space this screen is about; null while it is not known.
  final String? workspaceId, workspaceName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final id = workspaceId;
    if (id == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('money-my-finances-link'),
      color: theme.colorScheme.surfaceContainerLow,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n?.financesLinkTitle ?? 'Your finances across spaces',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n?.financesLinkBody ??
                  'Your invoices, reminders and payments from every space are '
                      'together in Me › Finances.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonal(
                key: const ValueKey('money-my-finances-open'),
                onPressed: () =>
                    context.push(myFinancesRoute(workspaceId: id)),
                child: Text(
                  l10n?.financesLinkAction(workspaceName ?? '') ??
                      'Open for ${workspaceName ?? ''}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

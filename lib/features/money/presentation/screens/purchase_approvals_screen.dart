// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3070 — the approvals queue: the purchase documents waiting for a decision,
// the one list behind the drawer's "To approve" entry and its count. A row
// opens the document with its decision bar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../providers/purchase_providers.dart';
import '../widgets/purchase_labels.dart';
import '../widgets/purchases_sheet.dart';
import 'money_view_data.dart';

/// `/money/purchases/approvals`.
class PurchaseApprovalsScreen extends ConsumerWidget {
  const PurchaseApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = MoneyViewData.gates(ref).workspace;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.purchaseApprovalsTitle)),
      body: workspace == null
          ? const SizedBox.shrink()
          : PurchaseApprovalsView(workspaceId: workspace.id),
    );
  }
}

/// The waiting documents of [workspaceId], loading, empty and refused
/// answered apart.
@visibleForTesting
class PurchaseApprovalsView extends ConsumerWidget {
  const PurchaseApprovalsView({required this.workspaceId, super.key});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final waiting = ref.watch(pendingApprovalsProvider(workspaceId));
    return waiting.when(
      loading: () => const LoadingView(),
      error: (_, _) => Padding(
        key: const ValueKey('approvals-error'),
        padding: AppSpacing.mdAll,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.purchaseApprovalsRefused),
            TextButton(
              key: const ValueKey('approvals-retry'),
              onPressed: () => ref.invalidate(purchasesProvider(workspaceId)),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
      data: (docs) => docs.isEmpty
          ? EmptyState(
              icon: Icons.task_alt_outlined,
              title: l10n.purchaseApprovalsEmpty,
            )
          : ListView(
              padding: AppSpacing.mdAll,
              children: [
                for (final p in docs)
                  ListTile(
                    key: ValueKey('approval-${p.id}'),
                    title: Text(
                      p.reference.isEmpty
                          ? purchaseKindLabel(l10n, p.kind)
                          : '${purchaseKindLabel(l10n, p.kind)} · ${p.reference}',
                    ),
                    subtitle: p.category.isEmpty ? null : Text(p.category),
                    trailing: Text(
                      moneyFormat(p.currency).formatMinor(p.grossCents),
                    ),
                    onTap: () async {
                      await showPurchaseForDecision(context, workspaceId, p.id);
                      ref.invalidate(purchasesProvider(workspaceId));
                    },
                  ),
              ],
            ),
    );
  }
}

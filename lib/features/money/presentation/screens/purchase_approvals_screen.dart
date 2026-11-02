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
import '../../domain/purchase_approval_reads.dart';
import '../../providers/purchase_approval_provider.dart';
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
class PurchaseApprovalsView extends ConsumerStatefulWidget {
  const PurchaseApprovalsView({required this.workspaceId, super.key});

  final String workspaceId;

  @override
  ConsumerState<PurchaseApprovalsView> createState() =>
      _PurchaseApprovalsViewState();
}

class _PurchaseApprovalsViewState extends ConsumerState<PurchaseApprovalsView> {
  final _cursors = <PurchaseApprovalCursor?>[null];

  void _restart() {
    ref.invalidate(purchaseApprovalPageProvider);
    setState(() {
      _cursors
        ..clear()
        ..add(null);
    });
  }

  @override
  void didUpdateWidget(PurchaseApprovalsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId) {
      _cursors
        ..clear()
        ..add(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pages = [
      for (final after in _cursors)
        ref.watch(
          purchaseApprovalPageProvider((
            workspaceId: widget.workspaceId,
            after: after,
          )),
        ),
    ];
    if (pages.any((p) => p.isLoading)) return const LoadingView();
    final resolved = [
      for (final p in pages)
        if (!p.hasError) p.requireValue,
    ];
    final ids = <String>{};
    final unstable =
        resolved.length != pages.length ||
        resolved.any(
          (p) =>
              p.count != resolved.first.count ||
              p.rows.any((r) => !ids.add(r.id)),
        ) ||
        [
          for (var i = 0; i < resolved.length - 1; i++)
            if (resolved[i].next != _cursors[i + 1]) i,
        ].isNotEmpty ||
        (resolved.isNotEmpty &&
            resolved.last.next != null &&
            _cursors.contains(resolved.last.next));
    if (unstable) {
      return Padding(
        key: const ValueKey('approvals-error'),
        padding: AppSpacing.mdAll,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.purchaseApprovalsRefused),
            TextButton(
              key: const ValueKey('approvals-retry'),
              onPressed: _restart,
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      );
    }
    final docs = [for (final page in resolved) ...page.rows];
    final next = resolved.last.next;
    return docs.isEmpty
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
                    await showPurchaseForDecision(
                      context,
                      widget.workspaceId,
                      p.id,
                    );
                    if (mounted) _restart();
                  },
                ),
              if (next != null)
                TextButton(
                  key: const ValueKey('approval-load-more'),
                  onPressed: () => setState(() => _cursors.add(next)),
                  child: Text(l10n.suppliersLoadMore),
                ),
            ],
          );
  }
}

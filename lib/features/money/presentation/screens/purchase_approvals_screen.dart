// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3070 — the approvals queue: the purchase documents waiting for a decision,
// the one list behind the drawer's "To approve" entry and its count. A row
// opens the document with its decision bar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/adaptive/window_class.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/purchase.dart';
import '../../domain/purchase_approval_reads.dart';
import '../../providers/purchase_approval_provider.dart';
import '../../providers/purchase_providers.dart';
import '../widgets/purchase_labels.dart';
import '../widgets/purchases_sheet.dart';
import 'money_view_data.dart';
import 'purchase_approvals_desk.dart';

/// The most of the page the receipts waiting below the table take.
const double _receiptsShare = 0.35;

/// `/money/purchases/approvals`.
class PurchaseApprovalsScreen extends ConsumerWidget {
  const PurchaseApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = MoneyViewData.gates(ref).workspace;
    return Scaffold(
      appBar: AppBar(title: PageTitle(context.l10n.purchaseApprovalsTitle)),
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

  /// #3615 — at the desk the waiting documents are a records table, the
  /// receipts waiting below it.
  bool get _desk =>
      WindowClass.of(context).index >= WindowClass.expanded.index;

  @override
  Widget build(BuildContext context) => _desk
      ? LayoutBuilder(
          builder: (context, box) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _billContent(context)),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: box.maxHeight * _receiptsShare,
                ),
                child: SingleChildScrollView(
                  padding: AppSpacing.mdAll,
                  child: _VisiblePendingReceipts(
                    workspaceId: widget.workspaceId,
                  ),
                ),
              ),
            ],
          ),
        )
      : ListView(
          padding: AppSpacing.mdAll,
          children: [
            _billContent(context),
            _VisiblePendingReceipts(workspaceId: widget.workspaceId),
          ],
        );

  /// #3615 — the waiting documents as the desk's records table.
  Widget _deskBills(
    List<PurchaseSummary> docs,
    PurchaseApprovalCursor? next,
  ) {
    final l10n = context.l10n;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: PurchaseApprovalsTable(
              workspaceId: widget.workspaceId,
              docs: docs,
              onOpen: (id) async {
                await showPurchaseForDecision(context, widget.workspaceId, id);
                if (mounted) _restart();
              },
              onDecided: () {
                if (mounted) _restart();
              },
            ),
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

  Widget _billContent(BuildContext context) {
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
              p.version != resolved.first.version ||
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
    if (_desk) return _deskBills(docs, next);
    return Column(
      children: [
        if (docs.isEmpty)
          EmptyState(
            icon: Icons.task_alt_outlined,
            title: l10n.purchaseApprovalsEmpty,
          ),
        for (final p in docs)
          ListTile(
            key: ValueKey('approval-${p.id}'),
            title: Text(
              p.reference.isEmpty
                  ? purchaseKindLabel(l10n, p.kind)
                  : '${purchaseKindLabel(l10n, p.kind)} · ${p.reference}',
            ),
            subtitle: p.category.isEmpty ? null : Text(p.category),
            trailing: Text(appFormatOf(context).moneyIn(p.currency).formatMinor(p.grossCents)),
            onTap: () async {
              await showPurchaseForDecision(context, widget.workspaceId, p.id);
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

/// The former queue also exposed RLS-visible pending receipts. This separate
/// read-only section uses the original purchase read and does not affect the
/// supplier-bill decision count or grant receipt validation rights.
class _VisiblePendingReceipts extends ConsumerWidget {
  const _VisiblePendingReceipts({required this.workspaceId});
  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final receipts = ref.watch(purchasesProvider(workspaceId));
    if (receipts.isLoading) return const LoadingView();
    if (receipts.hasError) {
      return Column(
        children: [
          Text(l10n.purchaseApprovalReceiptsUnavailable),
          TextButton(
            key: const ValueKey('approval-receipts-retry'),
            onPressed: () => ref.invalidate(purchasesProvider(workspaceId)),
            child: Text(l10n.commonRetry),
          ),
        ],
      );
    }
    final visible = receipts.requireValue.where(
      (p) =>
          p.kind == PurchaseKind.memberReceipt &&
          p.state == PurchaseState.pending,
    );
    if (visible.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.purchaseApprovalVisibleReceipts),
        for (final p in visible)
          ListTile(
            key: ValueKey('approval-receipt-${p.id}'),
            title: Text(
              p.reference.isEmpty
                  ? purchaseKindLabel(l10n, p.kind)
                  : '${purchaseKindLabel(l10n, p.kind)} · ${p.reference}',
            ),
            trailing: Text(appFormatOf(context).moneyIn(p.currency).formatMinor(p.grossCents)),
            onTap: () => showPurchaseDetail(context, workspaceId, p.id),
          ),
      ],
    );
  }
}

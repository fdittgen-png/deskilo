// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/purchase.dart';
import '../../providers/purchase_providers.dart';
import 'purchase_claims.dart';
import 'purchase_decision_bar.dart';
import 'purchase_dialogs.dart';
import 'purchase_labels.dart';
import 'purchase_payables.dart';

/// Opens the purchase documents of [workspaceId]. The caller decides when to
/// offer it; the server shows a member their own documents and a manager all.
Future<void> showPurchasesSheet(
  BuildContext context,
  String workspaceId, {
  required bool canCapture,
  bool canPay = false,
  bool canDecide = false,
  bool canOffset = false,
}) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => PurchasesView(
    workspaceId: workspaceId,
    canCapture: canCapture,
    canPay: canPay,
    canDecide: canDecide,
    canOffset: canOffset,
  ),
);

/// The list of documents, with the supplier-bill door for who may capture.
@visibleForTesting
class PurchasesView extends ConsumerStatefulWidget {
  const PurchasesView({
    required this.workspaceId,
    required this.canCapture,
    this.canPay = false,
    this.canDecide = false,
    this.canOffset = false,
    super.key,
  });

  final String workspaceId;

  /// Whether the signed-in person holds recordOutgoingPayments.
  final bool canPay;

  /// Whether the signed-in person holds approveExpenses.
  final bool canDecide;

  /// Whether the signed-in person may also settle invoices (issueInvoices).
  final bool canOffset;

  /// Whether the signed-in person holds managePurchases; the server decides
  /// again on every write.
  final bool canCapture;

  @override
  ConsumerState<PurchasesView> createState() => _PurchasesViewState();
}

class _PurchasesViewState extends ConsumerState<PurchasesView> {
  var _toPay = false;

  String get workspaceId => widget.workspaceId;

  Future<void> _add(BuildContext context) async {
    final saved = await showPurchaseBillDialog(context, workspaceId);
    if (saved != true || !context.mounted) return;
    ref.invalidate(purchasesProvider(workspaceId));
    AppSnack.success(context, context.l10n.purchasesSaved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final purchases =
        ref.watch(purchasesProvider(workspaceId)).value ??
        const <PurchaseSummary>[];
    return SheetShell(
      title: l10n.purchasesTitle,
      children: [
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<bool>(
          key: const ValueKey('purchases-tabs'),
          segments: [
            ButtonSegment(
              value: false,
              label: Text(l10n.purchasesTabDocuments),
            ),
            ButtonSegment(value: true, label: Text(l10n.purchasesTabToPay)),
          ],
          selected: {_toPay},
          onSelectionChanged: (s) => setState(() => _toPay = s.first),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_toPay)
          PurchasePayablesView(
            workspaceId: workspaceId,
            canPay: widget.canPay,
            canOffset: widget.canOffset,
            onOpen: (id) =>
                _showDetailSheet(context, workspaceId, id, widget),
          )
        else ...[
          Text(
            l10n.purchasesIntro,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (widget.canCapture) ...[
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              key: const ValueKey('purchase-add-bill'),
              onPressed: () => _add(context),
              icon: const Icon(Icons.add),
              label: Text(l10n.purchasesAddBill),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (purchases.isEmpty) Text(l10n.purchasesEmpty),
          ..._documents(context, purchases),
        ],
      ],
    );
  }

  List<Widget> _documents(BuildContext context, List<PurchaseSummary> purchases) {
    final l10n = context.l10n;
    return [
        for (final p in purchases)
          ListTile(
            key: ValueKey('purchase-${p.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              p.reference.isEmpty
                  ? purchaseKindLabel(l10n, p.kind)
                  : '${purchaseKindLabel(l10n, p.kind)} · ${p.reference}',
            ),
            subtitle: Text(
              [
                purchaseStateLabel(l10n, p.state),
                if (p.category.isNotEmpty) p.category,
              ].join(' · '),
            ),
            trailing: Text(moneyFormat(p.currency).formatMinor(p.grossCents)),
            onTap: () =>
                _showDetailSheet(context, workspaceId, p.id, widget),
          ),
    ];
  }
}

/// Opens one document with its lines and evidence.
Future<void> _showDetailSheet(
  BuildContext context,
  String workspaceId,
  String purchaseId,
  PurchasesView view,
) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _PurchaseDetailView(
    workspaceId: workspaceId,
    purchaseId: purchaseId,
    canPay: view.canPay,
    canCapture: view.canCapture,
    canDecide: view.canDecide,
  ),
);

/// #2573 — one document, read only, opened from elsewhere (the decision on
/// the expense request it was filed from): paying, capturing and deciding
/// stay on the purchases page.
Future<void> showPurchaseDetail(
  BuildContext context,
  String workspaceId,
  String purchaseId,
) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _PurchaseDetailView(
    workspaceId: workspaceId,
    purchaseId: purchaseId,
    canPay: false,
    canCapture: false,
    canDecide: false,
  ),
);

/// One purchase document as the server read it.
class _PurchaseDetailView extends ConsumerWidget {
  const _PurchaseDetailView({
    required this.workspaceId,
    required this.purchaseId,
    required this.canPay,
    required this.canCapture,
    required this.canDecide,
  });

  final String workspaceId;
  final String purchaseId;
  final bool canPay;
  final bool canCapture;
  final bool canDecide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final detail = ref
        .watch(
          purchaseDetailProvider((
            workspaceId: workspaceId,
            purchaseId: purchaseId,
          )),
        )
        .value;
    if (detail == null) {
      return SheetShell(
        title: l10n.purchasesTitle,
        children: const [LoadingView()],
      );
    }
    final s = detail.summary;
    final money = moneyFormat(s.currency);
    final supplier = detail.supplierName == null
        ? l10n.purchasesNoSupplier
        : '${detail.supplierNumber} · ${detail.supplierName}';
    return SheetShell(
      title: purchaseKindLabel(l10n, s.kind),
      children: [
        const SizedBox(height: AppSpacing.sm),
        Text(
          purchaseStateLabel(l10n, s.state),
          key: const ValueKey('purchase-state'),
          style: theme.textTheme.titleSmall,
        ),
        if (s.state == PurchaseState.draft &&
            s.kind != PurchaseKind.memberReceipt)
          Text(l10n.purchasesDraftNote),
        if (s.legacy) Text(l10n.purchasesLegacyTag),
        PurchaseDecisionBar(
          workspaceId: workspaceId,
          detail: detail,
          canCapture: canCapture,
          canDecide: canDecide,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('${l10n.purchasesSupplier}: $supplier'),
        if (s.reference.isNotEmpty)
          Text('${l10n.purchasesReference}: ${s.reference}'),
        if (detail.dueOn != null)
          Text(
            l10n.purchasesDueOn(
              MaterialLocalizations.of(context).formatMediumDate(detail.dueOn!),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.purchasesLines, style: theme.textTheme.titleSmall),
        for (final line in detail.lines)
          ListTile(
            key: ValueKey('purchase-line-${line.lineNo}'),
            contentPadding: EdgeInsets.zero,
            title: Text(line.description),
            subtitle: Text(
              line.taxStated
                  ? money.formatMinor(line.taxCents!)
                  : l10n.purchasesTaxNotStated,
            ),
            trailing: Text(money.formatMinor(line.grossCents)),
          ),
        Text(
          '${l10n.purchasesTotal}: ${money.formatMinor(detail.grossCents)}',
          key: const ValueKey('purchase-total'),
        ),
        if (detail.taxPartial && detail.lines.any((l) => l.taxStated))
          Text(l10n.purchasesTaxPartial),
        if (detail.obligations.isNotEmpty)
          PurchaseClaimsSection(
            workspaceId: workspaceId,
            claims: detail.obligations,
            canPay: canPay,
          ),
        if (detail.sources.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.purchasesEvidence, style: theme.textTheme.titleSmall),
          for (final src in detail.sources)
            ListTile(
              key: ValueKey('purchase-source-${src.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                src.kind == 'inbox'
                    ? l10n.purchasesSourceInbox(src.reference)
                    : l10n.purchasesSourceExpense,
              ),
            ),
        ],
      ],
    );
  }
}

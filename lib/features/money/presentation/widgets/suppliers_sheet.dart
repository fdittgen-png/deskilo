// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/supplier.dart';
import '../../providers/supplier_providers.dart';
import 'supplier_dialogs.dart';

/// #2567 — opens the suppliers of [workspaceId]. The caller decides when to
/// offer it; the server decides who may write. [lookupOn] offers Find
/// company details in the form (the `viesVerification` flag).
Future<void> showSuppliersSheet(
  BuildContext context,
  String workspaceId, {
  bool lookupOn = false,
}) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => SuppliersView(workspaceId: workspaceId, lookupOn: lookupOn),
);

/// The supplier list with what waits for review, add, edit, archive and the
/// bank-detail door.
@visibleForTesting
class SuppliersView extends ConsumerWidget {
  const SuppliersView({
    required this.workspaceId,
    this.lookupOn = false,
    super.key,
  });

  final String workspaceId;

  /// Whether the form may ask a company registry (#2863).
  final bool lookupOn;

  void _refresh(WidgetRef ref) {
    ref
      ..invalidate(suppliersProvider(workspaceId))
      ..invalidate(supplierReviewsProvider(workspaceId));
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Supplier? supplier,
  ) async {
    final result = await showSupplierDialog(
      context,
      supplier,
      lookupWorkspaceId: lookupOn ? workspaceId : null,
      existing: ref.read(suppliersProvider(workspaceId)).value ?? const [],
    );
    if (result == null || !context.mounted) return;
    // The lookup met a supplier already there: edit that one, create none.
    if (result is SupplierDialogOpenExisting) {
      return _edit(context, ref, result.supplier);
    }
    final draft = (result as SupplierDialogSave).draft;
    final l10n = context.l10n;
    String? saved;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'supplier save failed',
      errorText: l10n.suppliersRefused,
      action: () async => saved = await ref
          .read(supplierCommandProvider)
          .save(workspaceId, draft),
    );
    if (!ok || saved == null || !context.mounted) return;
    _refresh(ref);
    AppSnack.success(context, l10n.suppliersSaved);
  }

  Future<void> _archive(BuildContext context, WidgetRef ref, Supplier s) async {
    final command = ref.read(supplierCommandProvider);
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'supplier archive failed',
      errorText: context.l10n.suppliersRefused,
      action: () => s.isActive ? command.archive(s.id) : command.restore(s.id),
    );
    if (ok) _refresh(ref);
  }

  Future<void> _bank(BuildContext context, WidgetRef ref, Supplier s) async {
    final result = await showSupplierBankDialog(context, workspaceId, s);
    if (result == null || !context.mounted) return;
    final l10n = context.l10n;
    var revision = 0;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'supplier bank change failed',
      errorText: l10n.suppliersRefused,
      action: () async => revision = await ref
          .read(supplierCommandProvider)
          .changeBank(
            s.id,
            accountHolder: result.accountHolder,
            iban: result.iban,
            bic: result.bic,
          ),
    );
    if (!ok || !context.mounted) return;
    _refresh(ref);
    ref.invalidate(
      supplierBankHistoryProvider((workspaceId: workspaceId, supplierId: s.id)),
    );
    AppSnack.success(context, l10n.suppliersBankSaved(revision.toString()));
  }

  Future<void> _resolve(
    BuildContext context,
    WidgetRef ref,
    SupplierReview review,
    String? supplierId,
  ) async {
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'supplier review failed',
      errorText: context.l10n.suppliersRefused,
      action: () => ref
          .read(supplierCommandProvider)
          .resolveReview(review.id, supplierId),
    );
    if (!ok || !context.mounted) return;
    _refresh(ref);
    AppSnack.success(context, context.l10n.suppliersReviewDone);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final suppliers =
        ref.watch(suppliersProvider(workspaceId)).value ?? const <Supplier>[];
    final reviews =
        ref.watch(supplierReviewsProvider(workspaceId)).value ??
        const <SupplierReview>[];
    return SheetShell(
      title: l10n.suppliersTitle,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.suppliersIntro,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
          key: const ValueKey('supplier-add'),
          onPressed: () => _edit(context, ref, null),
          icon: const Icon(Icons.add),
          label: Text(l10n.suppliersAdd),
        ),
        if (reviews.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.suppliersReviewTitle, style: theme.textTheme.titleSmall),
          for (final r in reviews)
            _ReviewTile(
              review: r,
              suppliers: suppliers,
              onResolve: (id) => _resolve(context, ref, r, id),
            ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (suppliers.isEmpty) Text(l10n.suppliersEmpty),
        for (final s in suppliers)
          ListTile(
            key: ValueKey('supplier-${s.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${s.number} · ${s.name}'
              '${s.isActive ? '' : ' (${l10n.suppliersArchivedTag})'}',
            ),
            subtitle: Text(_taxLine(l10n, s)),
            trailing: Wrap(
              children: [
                IconButton(
                  key: ValueKey('supplier-edit-${s.id}'),
                  tooltip: l10n.suppliersEdit,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _edit(context, ref, s),
                ),
                IconButton(
                  key: ValueKey('supplier-bank-${s.id}'),
                  tooltip: l10n.suppliersBank,
                  icon: const Icon(Icons.account_balance_outlined),
                  onPressed: () => _bank(context, ref, s),
                ),
                IconButton(
                  key: ValueKey('supplier-archive-${s.id}'),
                  tooltip: s.isActive
                      ? l10n.suppliersArchive
                      : l10n.suppliersRestore,
                  icon: Icon(
                    s.isActive
                        ? Icons.archive_outlined
                        : Icons.unarchive_outlined,
                  ),
                  onPressed: () => _archive(context, ref, s),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _taxLine(AppLocalizations l10n, Supplier s) {
    if (s.taxIdEntered.isEmpty) return l10n.suppliersTaxUnverified;
    final tag = s.isVerified
        ? l10n.suppliersTaxVerified
        : l10n.suppliersTaxUnverified;
    return '${s.taxIdEntered} · $tag';
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.review,
    required this.suppliers,
    required this.onResolve,
  });

  final SupplierReview review;
  final List<Supplier> suppliers;
  final void Function(String? supplierId) onResolve;

  String _text(AppLocalizations l10n) => switch (review.reason) {
    SupplierReviewReason.missingIdentifier => l10n.suppliersReviewMissing(
      review.sourceName,
    ),
    SupplierReviewReason.unverifiedIdentifier => l10n.suppliersReviewUnverified(
      review.sourceName,
      review.sourceIdentifier,
    ),
    SupplierReviewReason.groupIdentifier => l10n.suppliersReviewGroup(
      review.sourceName,
      review.sourceIdentifier,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final candidates = [
      for (final s in suppliers)
        if (review.candidateIds.contains(s.id)) s,
    ];
    return Padding(
      key: ValueKey('supplier-review-${review.id}'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_text(l10n)),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final c in candidates)
                TextButton(
                  key: ValueKey('supplier-review-link-${c.id}'),
                  onPressed: () => onResolve(c.id),
                  child: Text(l10n.suppliersReviewLinkTo(c.name)),
                ),
              TextButton(
                key: ValueKey('supplier-review-new-${review.id}'),
                onPressed: () => onResolve(null),
                child: Text(l10n.suppliersReviewNew),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

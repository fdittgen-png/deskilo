// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 (part 2) — my groups on Me › Finances, beside the workspace filter:
// one chip per group narrows the lists to what it names; the chosen group's
// header says how many invoices it names and what they come to, one total
// per currency (never one figure across currencies), and names each invoice
// that cannot be read now, left out of the totals. Rename, delete, and
// removing an unreadable invoice are here; filing an invoice is on its row.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../domain/invoice_groups.dart';
import '../../providers/invoice_group_providers.dart';
import 'invoice_group_rename.dart';

class InvoiceGroupsBar extends ConsumerWidget {
  const InvoiceGroupsBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  /// The chosen group's id; none chosen when null.
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final read = ref.watch(invoiceGroupsProvider);
    // a failed read is said, with Try again: never an absence of groups
    if (read case AsyncError(:final error) when !read.hasValue) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: ReadFailureBanner(
          error: error,
          onRetry: () => ref.invalidate(invoiceGroupsProvider),
        ),
      );
    }
    final groups = read.value;
    if (groups == null || groups.isEmpty) return const SizedBox.shrink();
    final view = selected == null
        ? null
        : ref.watch(invoiceGroupViewsProvider)[selected];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.portalGroupsHeading,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              for (final g in groups)
                ChoiceChip(
                  key: ValueKey('finances-group-filter-${g.id}'),
                  label: Text(g.name),
                  selected: g.id == selected,
                  onSelected: (on) => onSelected(on ? g.id : null),
                ),
            ],
          ),
          if (view != null)
            _GroupHeader(view: view, onDeleted: () => onSelected(null)),
        ],
      ),
    );
  }
}

class _GroupHeader extends ConsumerWidget {
  const _GroupHeader({required this.view, required this.onDeleted});

  final InvoiceGroupView view;
  final VoidCallback onDeleted;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('finances-group-delete-confirm'),
        content: Text(l10n.financesGroupDeleteConfirm(view.group.name)),
        actions: [
          TextButton(
            key: const ValueKey('finances-group-delete-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('finances-group-delete-yes'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(MaterialLocalizations.of(context).deleteButtonTooltip),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'invoice group delete failed',
      errorText: l10n.financesGroupFailed,
      action: () =>
          ref.read(invoiceGroupsProvider.notifier).delete(view.group.id),
    );
    if (ok) onDeleted();
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, InvoiceRef item) =>
      runGuarded(
        context,
        domain: 'money',
        message: 'invoice group remove failed',
        errorText: context.l10n.financesGroupFailed,
        action: () => ref
            .read(invoiceGroupsProvider.notifier)
            .remove(view.group.id, item),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final format = personalFormatOf(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final totals = [
      for (final (currency, cents) in view.totals)
        format.moneyNamed(currency).formatMinor(cents),
    ].join(' · ');
    return Card(
      key: const ValueKey('finances-group-header'),
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    view.group.name,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const ValueKey('finances-group-rename'),
                  tooltip: l10n.financesGroupRename,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => showInvoiceGroupRename(context, view.group),
                ),
                IconButton(
                  key: const ValueKey('finances-group-delete'),
                  tooltip: l10n.financesGroupDelete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(context, ref),
                ),
              ],
            ),
            Text(
              l10n.invoicingInvoiceCount(view.count),
              key: const ValueKey('finances-group-count'),
              style: muted,
            ),
            if (totals.isNotEmpty)
              Text(
                totals,
                key: const ValueKey('finances-group-totals'),
                style: theme.textTheme.titleSmall,
              ),
            if (view.unreadable.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.financesGroupUnreadable(view.unreadable.length),
                key: const ValueKey('finances-group-unreadable'),
                style: muted,
              ),
              for (final (i, item) in view.unreadable.indexed)
                ListTile(
                  key: ValueKey('finances-group-unreadable-$i'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(l10n.financesGroupUnreadableItem(item.number)),
                  trailing: IconButton(
                    key: ValueKey('finances-group-unreadable-remove-$i'),
                    tooltip: l10n.financesGroupRemove,
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _remove(context, ref, item.ref),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

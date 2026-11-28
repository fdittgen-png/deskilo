// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4512 -- Master data › Expense categories: the categories an expense or a receipt is filed under, as the business keeps them.
// The owner adds one, renames one, puts them in order and retires one that is no longer used (it stays on what was filed under
// it, and can be brought back). Nothing is deleted.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/server_error.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/adaptive/page_measures.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/expense_category.dart';
import '../../providers/expense_category_providers.dart';
import '../expense_category_names.dart';

/// What the server's refusal of a category says, by the reason it names.
String _problem(AppLocalizations l10n, Object error) => switch (serverErrorDetails(error)) {
  'label_taken' => l10n.expenseCategoryNameTaken,
  'label_required' => l10n.expenseCategoryNameRequired,
  _ => l10n.expenseCategorySaveFailed,
};

class ExpenseCategoriesScreen extends ConsumerWidget {
  const ExpenseCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.expenseCategoriesTitle),
        actions: [HelpDot(l10n.expenseCategoriesTitle, anchor: HelpAnchor.moneyExpenseCategories)],
      ),
      floatingActionButton: workspace == null
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('expense-category-add'),
              onPressed: () => _open(context, ref, workspace.id, null),
              icon: const Icon(Icons.add),
              label: Text(l10n.expenseCategoryAdd),
            ),
      body: workspace == null
          ? const SizedBox.shrink()
          : SingleChildScrollView(
              padding: AppSpacing.gutterAll,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: kFormColumnWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.expenseCategoriesSubtitle),
                      const FormGap(),
                      AsyncReadBody<List<ExpenseCategory>>.part(
                        value: ref.watch(expenseCategoriesProvider(workspace.id)),
                        onRetry: () => ref.invalidate(expenseCategoriesProvider(workspace.id)),
                        data: (all) => _Lists(workspaceId: workspace.id, all: all),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// Asks the server to do [action] and says what it refused; refreshes the list when it was done.
Future<void> _run(BuildContext context, WidgetRef ref, String workspaceId, Future<void> Function() action) async {
  final l10n = context.l10n;
  final problem = await guardSave(
    domain: 'money',
    message: 'expense category change failed',
    action: action,
    problem: (e) => _problem(l10n, e),
  );
  ref.invalidate(expenseCategoriesProvider(workspaceId));
  if (problem != null && context.mounted) AppSnack.error(context, problem);
}

Future<void> _open(BuildContext context, WidgetRef ref, String workspaceId, ExpenseCategory? category) async {
  final l10n = context.l10n;
  final repo = ref.read(expenseCategoryRepositoryProvider);
  final fields = FormControllers({'categoryName': category?.label ?? ''});
  await showAppFormSheet(
    context,
    AppFormSheet(
      title: category == null ? l10n.expenseCategoryNewTitle : l10n.expenseCategoryEditTitle,
      submitLabel: MaterialLocalizations.of(context).saveButtonLabel,
      submitKey: const ValueKey('expense-category-save'),
      onDispose: fields.dispose,
      validate: () => {
        if (fields.text('categoryName').trim().isEmpty && !(category?.builtIn ?? false)) 'categoryName': l10n.expenseCategoryNameRequired,
      },
      onSubmit: () => guardSave(
        domain: 'money',
        message: 'save expense category failed',
        action: () async {
          await repo.save(workspaceId, id: category?.id, label: fields.text('categoryName').trim(), requestId: newRequestId());
          ref.invalidate(expenseCategoriesProvider(workspaceId));
        },
        problem: (e) => _problem(l10n, e),
      ),
      builder: (context, refresh) => [
        AppTextField(
          key: const ValueKey('expense-category-name'),
          controller: fields['categoryName'],
          fieldKey: 'categoryName',
          label: l10n.expenseCategoryName,
          helper: l10n.expenseCategoryNameHint,
          autofocus: true,
        ),
      ],
    ),
  );
}

class _Lists extends ConsumerWidget {
  const _Lists({required this.workspaceId, required this.all});

  final String workspaceId;
  final List<ExpenseCategory> all;

  /// Puts the active categories in the order of [ids]: each one that is not at its place is saved with it.
  Future<void> _order(BuildContext context, WidgetRef ref, List<ExpenseCategory> active, int from, int to) async {
    final repo = ref.read(expenseCategoryRepositoryProvider);
    final moved = [...active];
    moved.insert(to, moved.removeAt(from));
    await _run(context, ref, workspaceId, () async {
      for (final (i, c) in moved.indexed) {
        if (c.sortOrder != (i + 1) * 10) {
          await repo.save(workspaceId, id: c.id, label: c.label, sortOrder: (i + 1) * 10, requestId: newRequestId());
        }
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final active = activeExpenseCategories(all);
    final retired = [
      for (final c in all)
        if (c.retired) c,
    ];
    final repo = ref.read(expenseCategoryRepositoryProvider);
    if (active.isEmpty && retired.isEmpty) return Text(l10n.expenseCategoriesEmpty, key: const ValueKey('expense-categories-none'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, c) in active.indexed)
          Card(
            key: ValueKey('expense-category-${c.id}'),
            child: ListTile(
              key: ValueKey('expense-category-open-${c.id}'),
              title: Text(expenseCategoryName(l10n, c)),
              subtitle: c.builtIn ? Text(l10n.expenseCategoryBuiltInMark) : null,
              onTap: () => _open(context, ref, workspaceId, c),
              trailing: Wrap(
                children: [
                  IconButton(
                    key: ValueKey('expense-category-up-${c.id}'),
                    tooltip: l10n.expenseCategoryMoveUp,
                    icon: const Icon(Icons.arrow_upward),
                    onPressed: i == 0 ? null : () => _order(context, ref, active, i, i - 1),
                  ),
                  IconButton(
                    key: ValueKey('expense-category-down-${c.id}'),
                    tooltip: l10n.expenseCategoryMoveDown,
                    icon: const Icon(Icons.arrow_downward),
                    onPressed: i == active.length - 1 ? null : () => _order(context, ref, active, i, i + 1),
                  ),
                  IconButton(
                    key: ValueKey('expense-category-retire-${c.id}'),
                    tooltip: l10n.expenseCategoryRetire,
                    icon: const Icon(Icons.archive_outlined),
                    onPressed: () => _run(context, ref, workspaceId, () async {
                      await repo.setRetired(workspaceId, c.id, retired: true, requestId: newRequestId());
                    }),
                  ),
                ],
              ),
            ),
          ),
        if (retired.isNotEmpty) ...[
          const FormGap.large(),
          Text(l10n.expenseCategoryRetiredSection, style: Theme.of(context).textTheme.titleSmall),
          const FormGap.small(),
          for (final c in retired)
            Card(
              key: ValueKey('expense-category-${c.id}'),
              child: ListTile(
                title: Text(expenseCategoryName(l10n, c)),
                subtitle: Text(l10n.expenseCategoryRetiredMark),
                trailing: TextButton(
                  key: ValueKey('expense-category-restore-${c.id}'),
                  onPressed: () => _run(context, ref, workspaceId, () async {
                    await repo.setRetired(workspaceId, c.id, retired: false, requestId: newRequestId());
                  }),
                  child: Text(l10n.expenseCategoryRestore),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

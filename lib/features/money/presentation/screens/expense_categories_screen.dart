// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4512 -- Master data › Expense categories: the categories an expense or a receipt is filed under, as the business keeps them.
// The owner adds one, renames one, puts them in order and retires one that is no longer used (it stays on what was filed under
// it, and can be brought back). Nothing is deleted.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/adaptive/page_measures.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/expense_category_commands.dart';
import '../../domain/expense_category.dart';
import '../../providers/expense_category_providers.dart';
import '../expense_category_names.dart';

/// What the refusal of a change says.
String _problemText(AppLocalizations l10n, ExpenseCategoryProblem problem) => switch (problem) {
  ExpenseCategoryProblem.nameTaken => l10n.expenseCategoryNameTaken,
  ExpenseCategoryProblem.nameRequired => l10n.expenseCategoryNameRequired,
  ExpenseCategoryProblem.failed => l10n.expenseCategorySaveFailed,
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
              onPressed: () => _Editor.open(context, ref, workspace.id, null),
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

/// What the page does: the sheet of a category, and the changes the cards make.
abstract final class _Editor {
  /// Says what the server refused, and reads the list again.
  static Future<void> done(BuildContext context, WidgetRef ref, String workspaceId, ExpenseCategoryProblem? problem) async {
    ref.invalidate(expenseCategoriesProvider(workspaceId));
    if (problem != null && context.mounted) AppSnack.error(context, _problemText(context.l10n, problem));
  }

  static Future<void> open(BuildContext context, WidgetRef ref, String workspaceId, ExpenseCategory? category) async {
    final l10n = context.l10n;
    final commands = ref.read(expenseCategoryCommandsProvider);
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
        onSubmit: () async {
          final problem = await commands.save(workspaceId, id: category?.id, label: fields.text('categoryName'));
          ref.invalidate(expenseCategoriesProvider(workspaceId));
          return problem == null ? null : _problemText(l10n, problem);
        },
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
}

class _Lists extends ConsumerWidget {
  const _Lists({required this.workspaceId, required this.all});

  final String workspaceId;
  final List<ExpenseCategory> all;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final commands = ref.read(expenseCategoryCommandsProvider);
    final active = activeExpenseCategories(all);
    final retired = [
      for (final c in all)
        if (c.retired) c,
    ];
    if (active.isEmpty && retired.isEmpty) return Text(l10n.expenseCategoriesEmpty, key: const ValueKey('expense-categories-none'));
    Future<void> move(int from, int to) async {
      final problem = await commands.move(workspaceId, active, from, to);
      if (context.mounted) await _Editor.done(context, ref, workspaceId, problem);
    }

    Future<void> retire(ExpenseCategory c, {required bool retired}) async {
      final problem = await commands.setRetired(workspaceId, c.id, retired: retired);
      if (context.mounted) await _Editor.done(context, ref, workspaceId, problem);
    }

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
              onTap: () => _Editor.open(context, ref, workspaceId, c),
              trailing: Wrap(
                children: [
                  IconButton(
                    key: ValueKey('expense-category-up-${c.id}'),
                    tooltip: l10n.expenseCategoryMoveUp,
                    icon: const Icon(Icons.arrow_upward),
                    onPressed: i == 0 ? null : () => move(i, i - 1),
                  ),
                  IconButton(
                    key: ValueKey('expense-category-down-${c.id}'),
                    tooltip: l10n.expenseCategoryMoveDown,
                    icon: const Icon(Icons.arrow_downward),
                    onPressed: i == active.length - 1 ? null : () => move(i, i + 1),
                  ),
                  IconButton(
                    key: ValueKey('expense-category-retire-${c.id}'),
                    tooltip: l10n.expenseCategoryRetire,
                    icon: const Icon(Icons.archive_outlined),
                    onPressed: () => retire(c, retired: true),
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
                  onPressed: () => retire(c, retired: false),
                  child: Text(l10n.expenseCategoryRestore),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

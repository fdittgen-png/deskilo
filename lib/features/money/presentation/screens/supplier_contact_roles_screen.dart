// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4518 -- Master data › Contact roles: the roles a business gives the contacts of its suppliers (orders, invoices, delivery, accounting,
// its own). It adds one, renames one, puts them in order and retires one that is no longer used (it stays on the contacts that hold it,
// and can be brought back). Nothing is deleted.
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
import '../../application/supplier_contact_commands.dart';
import '../../domain/supplier_contact.dart';
import '../../providers/bank_statement_providers.dart' show currentWorkspaceProvider;
import '../../providers/supplier_contact_providers.dart';
import '../supplier_contact_names.dart';

/// What the refusal of a change says.
String _problemText(AppLocalizations l10n, SupplierContactProblem problem) => switch (problem) {
  SupplierContactProblem.nameTaken => l10n.supplierContactRoleNameTaken,
  SupplierContactProblem.nameRequired => l10n.supplierContactRoleNameRequired,
  _ => l10n.supplierContactSaveFailed,
};

class SupplierContactRolesScreen extends ConsumerWidget {
  const SupplierContactRolesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.supplierContactRolesTitle),
        actions: [HelpDot(l10n.supplierContactRolesTitle, anchor: HelpAnchor.moneySupplierContacts)],
      ),
      floatingActionButton: workspace == null
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('supplier-contact-role-add'),
              onPressed: () => _Editor.open(context, ref, workspace.id, null),
              icon: const Icon(Icons.add),
              label: Text(l10n.supplierContactRoleAdd),
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
                      Text(l10n.supplierContactRolesSubtitle),
                      const FormGap(),
                      AsyncReadBody<List<SupplierContactRole>>.part(
                        value: ref.watch(supplierContactRolesProvider(workspace.id)),
                        onRetry: () => ref.invalidate(supplierContactRolesProvider(workspace.id)),
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

/// What the page does: the sheet of a role, and the changes the cards make.
abstract final class _Editor {
  /// Says what the server refused, and reads the list again.
  static Future<void> done(BuildContext context, WidgetRef ref, String workspaceId, SupplierContactProblem? problem) async {
    ref.invalidate(supplierContactRolesProvider(workspaceId));
    if (problem != null && context.mounted) AppSnack.error(context, _problemText(context.l10n, problem));
  }

  static Future<void> open(BuildContext context, WidgetRef ref, String workspaceId, SupplierContactRole? role) async {
    final l10n = context.l10n;
    final commands = ref.read(supplierContactCommandsProvider);
    final fields = FormControllers({'roleName': role?.label ?? ''});
    await showAppFormSheet(
      context,
      AppFormSheet(
        title: role == null ? l10n.supplierContactRoleNewTitle : l10n.supplierContactRoleEditTitle,
        submitLabel: MaterialLocalizations.of(context).saveButtonLabel,
        submitKey: const ValueKey('supplier-contact-role-save'),
        onDispose: fields.dispose,
        validate: () => {
          if (fields.text('roleName').trim().isEmpty && !(role?.builtIn ?? false)) 'roleName': l10n.supplierContactRoleNameRequired,
        },
        onSubmit: () async {
          final problem = await commands.saveRole(workspaceId, id: role?.id, label: fields.text('roleName'));
          ref.invalidate(supplierContactRolesProvider(workspaceId));
          return problem == null ? null : _problemText(l10n, problem);
        },
        builder: (context, refresh) => [
          AppTextField(
            key: const ValueKey('supplier-contact-role-name'),
            controller: fields['roleName'],
            fieldKey: 'roleName',
            label: l10n.supplierContactRoleName,
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
  final List<SupplierContactRole> all;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final commands = ref.read(supplierContactCommandsProvider);
    final active = activeSupplierContactRoles(all);
    final retired = [
      for (final c in all)
        if (c.retired) c,
    ];
    if (active.isEmpty && retired.isEmpty) return Text(l10n.supplierContactRolesEmpty, key: const ValueKey('supplier-contact-roles-none'));
    Future<void> move(int from, int to) async {
      final problem = await commands.moveRole(workspaceId, active, from, to);
      if (context.mounted) await _Editor.done(context, ref, workspaceId, problem);
    }

    Future<void> retire(SupplierContactRole c, {required bool retired}) async {
      final problem = await commands.setRoleRetired(workspaceId, c.id, retired: retired);
      if (context.mounted) await _Editor.done(context, ref, workspaceId, problem);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, c) in active.indexed)
          Card(
            key: ValueKey('supplier-contact-role-${c.id}'),
            child: ListTile(
              key: ValueKey('supplier-contact-role-open-${c.id}'),
              title: Text(supplierContactRoleName(l10n, c)),
              subtitle: c.builtIn ? Text(l10n.expenseCategoryBuiltInMark) : null,
              onTap: () => _Editor.open(context, ref, workspaceId, c),
              trailing: Wrap(
                children: [
                  IconButton(
                    key: ValueKey('supplier-contact-role-up-${c.id}'),
                    tooltip: l10n.expenseCategoryMoveUp,
                    icon: const Icon(Icons.arrow_upward),
                    onPressed: i == 0 ? null : () => move(i, i - 1),
                  ),
                  IconButton(
                    key: ValueKey('supplier-contact-role-down-${c.id}'),
                    tooltip: l10n.expenseCategoryMoveDown,
                    icon: const Icon(Icons.arrow_downward),
                    onPressed: i == active.length - 1 ? null : () => move(i, i + 1),
                  ),
                  IconButton(
                    key: ValueKey('supplier-contact-role-retire-${c.id}'),
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
          Text(l10n.supplierContactRoleRetiredSection, style: Theme.of(context).textTheme.titleSmall),
          const FormGap.small(),
          for (final c in retired)
            Card(
              key: ValueKey('supplier-contact-role-${c.id}'),
              child: ListTile(
                title: Text(supplierContactRoleName(l10n, c)),
                subtitle: Text(l10n.expenseCategoryRetiredMark),
                trailing: TextButton(
                  key: ValueKey('supplier-contact-role-restore-${c.id}'),
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

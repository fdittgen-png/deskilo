// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1923 C — saved views on the Web-BI page: open, save, save as, rename,
// duplicate, delete, and the default a bare /bi opens (mine first, then
// the team's). Only a definition is saved — the question, never the
// figures or the rights — and a team view or the team default is
// offered only to someone who manages the workspace; the server checks
// it again. A refused write says why (someone saved it meanwhile, the
// name is taken, it is not yours) and the list is read again.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/bi_query.dart';
import '../../domain/bi_saved_view.dart';
import '../../domain/workspace_permission.dart';
import '../../providers/bi_providers.dart';
import '../../providers/workspace_providers.dart';
import 'bi_view_dialogs.dart';
import 'bi_view_failure_text.dart';

/// Opens [view] (its id goes into the address as `saved`) or, with
/// null, the product standard.
typedef BiOpenView = void Function(BiSavedView? view, BiQueryContext query);

class BiViewsBar extends ConsumerWidget {
  const BiViewsBar({
    super.key,
    required this.workspaceId,
    required this.query,
    required this.openId,
    required this.visibleModules,
    required this.today,
    required this.onOpen,
  });

  final String workspaceId;
  final BiQueryContext query;

  /// The `saved` address parameter: a view id, or null.
  final String? openId;

  /// The module ids this reader may see now.
  final Set<String> visibleModules;
  final DateTime today;
  final BiOpenView onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final views = ref.watch(biViewsProvider(workspaceId)).value ?? const [];
    final canManage = ref
        .watch(myPermissionsProvider)
        .contains(WorkspacePermission.workspaceSettings);
    final open = views.where((v) => v.id == openId).firstOrNull;
    final opened = open == null
        ? null
        : checkView(open.definition, visibleModules).query;
    final modified = open != null && opened != query;
    final menu = _ViewsMenu(
      context: context,
      l10n: l10n,
      workspaceId: workspaceId,
      query: query,
      today: today,
      visibleModules: visibleModules,
      onOpen: onOpen,
      views: views,
      open: open,
      canManage: canManage,
      actions: ref.read(biViewActionsProvider),
    );
    final items = menu.items();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        children: [
          PopupMenuButton<void Function()>(
            key: const ValueKey('bi-views'),
            tooltip: l10n.biViews,
            itemBuilder: (_) => items,
            onSelected: (action) => action(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bookmarks_outlined),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  open == null
                      ? l10n.biViewStandard
                      : menu.label(open),
                  key: const ValueKey('bi-views-current'),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
          if (modified)
            Text(
              l10n.biViewModified,
              key: const ValueKey('bi-views-modified'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

/// The entries of the views menu: what each one does, written once and
/// built from the reads [BiViewsBar] already made.
class _ViewsMenu {
  _ViewsMenu({
    required this.context,
    required this.l10n,
    required this.workspaceId,
    required this.query,
    required this.today,
    required this.visibleModules,
    required this.onOpen,
    required this.views,
    required this.open,
    required this.canManage,
    required this.actions,
  });

  final BuildContext context;
  final AppLocalizations l10n;
  final String workspaceId;
  final BiQueryContext query;
  final DateTime today;
  final Set<String> visibleModules;
  final BiOpenView onOpen;
  final List<BiSavedView> views;
  final BiSavedView? open;
  final bool canManage;
  final BiViewActions actions;

  bool editable(BiSavedView v) =>
      v.scope == BiViewScope.private ? v.mine : canManage;

  String label(BiSavedView v) => '${v.name}${v.isDefault ? ' ★' : ''}';

  Future<void> run(Future<void> Function() write) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await write();
    } on BiViewRefused catch (e, st) {
      TraceLogger.instance.warn(
        'bi',
        'saved view write refused: ${e.failure.name}',
        error: e,
        stackTrace: st,
      );
      messenger.showSnackBar(
        SnackBar(content: Text(biViewFailureText(l10n, e.failure))),
      );
    }
  }

  List<PopupMenuEntry<void Function()>> items() {
    final view = open;
    final myDefault = views.any(
      (v) => v.scope == BiViewScope.private && v.mine && v.isDefault,
    );
    final teamDefault = views.any(
      (v) => v.scope == BiViewScope.workspace && v.isDefault,
    );
    return [
      PopupMenuItem(
        key: const ValueKey('bi-views-standard'),
        value: () => onOpen(null, BiQueryContext.standard),
        child: Text(l10n.biViewStandard),
      ),
      for (final scope in BiViewScope.values)
        if (views.any((v) => v.scope == scope)) ..._scopeEntries(scope),
      const PopupMenuDivider(),
      if (view != null && editable(view)) _save(view),
      _saveAs(),
      if (view != null) ..._openViewEntries(view),
      if (myDefault)
        PopupMenuItem(
          key: const ValueKey('bi-views-clear-my-default'),
          value: () => run(
            () => actions.setDefault(workspaceId, BiViewScope.private, null),
          ),
          child: Text(l10n.biViewClearMyDefault),
        ),
      if (teamDefault && canManage)
        PopupMenuItem(
          key: const ValueKey('bi-views-clear-team-default'),
          value: () => run(
            () => actions.setDefault(workspaceId, BiViewScope.workspace, null),
          ),
          child: Text(l10n.biViewClearTeamDefault),
        ),
    ];
  }

  List<PopupMenuEntry<void Function()>> _scopeEntries(BiViewScope scope) => [
    const PopupMenuDivider(),
    PopupMenuItem(
      enabled: false,
      child: Text(
        scope == BiViewScope.private ? l10n.biViewsMine : l10n.biViewsTeam,
      ),
    ),
    for (final v in views.where((v) => v.scope == scope))
      PopupMenuItem(
        key: ValueKey('bi-views-open-${v.id}'),
        value: () {
          final check = checkView(v.definition, visibleModules);
          if (check.query == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.biViewUnreadable)),
            );
            return;
          }
          onOpen(v, check.query!);
        },
        child: Text(label(v)),
      ),
  ];

  PopupMenuEntry<void Function()> _save(BiSavedView view) => PopupMenuItem(
    key: const ValueKey('bi-views-save'),
    value: () => run(() async {
      final saved = await actions.save(
        workspaceId,
        over: view,
        scope: view.scope,
        name: view.name,
        definition: biSavedDefinition(view, query),
      );
      onOpen(saved, query);
    }),
    child: Text(l10n.biViewSave),
  );

  PopupMenuEntry<void Function()> _saveAs() => PopupMenuItem(
    key: const ValueKey('bi-views-save-as'),
    value: () => run(() async {
      final answer = await showDialog<BiSaveAnswer>(
        context: context,
        builder: (_) => BiSaveDialog(
          query: query,
          today: today,
          canShare: canManage,
          initialName: '',
        ),
      );
      if (answer == null) return;
      final saved = await actions.save(
        workspaceId,
        scope: answer.scope,
        name: answer.name,
        definition: BiViewDefinition.of(answer.query),
      );
      onOpen(saved, answer.query);
    }),
    child: Text(l10n.biViewSaveAs),
  );

  List<PopupMenuEntry<void Function()>> _openViewEntries(BiSavedView open) => [
    if (editable(open)) _rename(open),
    PopupMenuItem(
      key: const ValueKey('bi-views-duplicate'),
      value: () => run(() async {
        final copy = await actions.save(
          workspaceId,
          scope: BiViewScope.private,
          name: l10n.biViewCopyName(open.name),
          definition: BiViewDefinition.of(query),
        );
        onOpen(copy, query);
      }),
      child: Text(l10n.biViewDuplicate),
    ),
    if (open.scope == BiViewScope.private && open.mine && !open.isDefault)
      PopupMenuItem(
        key: const ValueKey('bi-views-my-default'),
        value: () => run(
          () => actions.setDefault(workspaceId, BiViewScope.private, open.id),
        ),
        child: Text(l10n.biViewMakeMyDefault),
      ),
    if (open.scope == BiViewScope.workspace && canManage && !open.isDefault)
      PopupMenuItem(
        key: const ValueKey('bi-views-team-default'),
        value: () => run(
          () => actions.setDefault(workspaceId, BiViewScope.workspace, open.id),
        ),
        child: Text(l10n.biViewMakeTeamDefault),
      ),
    if (editable(open)) _delete(open),
  ];

  PopupMenuEntry<void Function()> _rename(BiSavedView open) => PopupMenuItem(
    key: const ValueKey('bi-views-rename'),
    value: () => run(() async {
      final name = await showDialog<String>(
        context: context,
        builder: (_) => BiNameDialog(initial: open.name),
      );
      if (name == null) return;
      await actions.save(
        workspaceId,
        over: open,
        scope: open.scope,
        name: name,
        definition: open.definition ?? BiViewDefinition.of(query),
      );
    }),
    child: Text(l10n.biViewRename),
  );

  PopupMenuEntry<void Function()> _delete(BiSavedView open) => PopupMenuItem(
    key: const ValueKey('bi-views-delete'),
    value: () => run(() async {
      final yes = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          content: Text(l10n.biViewDeleteConfirm(open.name)),
          actions: [
            TextButton(
              key: const ValueKey('bi-view-delete-cancel'),
              onPressed: () => Navigator.of(dialog).pop(false),
              child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
            ),
            TextButton(
              key: const ValueKey('bi-views-delete-confirm'),
              onPressed: () => Navigator.of(dialog).pop(true),
              child: Text(l10n.biViewDelete),
            ),
          ],
        ),
      );
      if (yes != true) return;
      await actions.delete(workspaceId, open);
      onOpen(null, query);
    }),
    child: Text(l10n.biViewDelete),
  );
}

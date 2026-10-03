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

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/bi_query.dart';
import '../../domain/bi_saved_view.dart';
import '../../domain/workspace_permission.dart';
import '../../providers/bi_providers.dart';
import '../../providers/workspace_providers.dart';
import 'bi_toolbar.dart';

/// Opens [view] (its id goes into the address as `saved`) or, with
/// null, the product standard.
typedef BiOpenView = void Function(BiSavedView? view, BiQueryContext query);

String biViewFailureText(AppLocalizations? l10n, BiViewFailure f) =>
    switch (f) {
      BiViewFailure.stale =>
        l10n?.biViewStale ??
            'Someone saved this view since you opened it. The list was read '
                'again; try once more.',
      BiViewFailure.nameTaken =>
        l10n?.biViewNameTaken ?? 'A view with this name already exists.',
      BiViewFailure.forbidden =>
        l10n?.biViewForbidden ?? 'You may not change this view.',
      BiViewFailure.invalid =>
        l10n?.biViewInvalid ?? 'This name or view cannot be saved.',
    };

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
    final l10n = AppLocalizations.of(context);
    final views = ref.watch(biViewsProvider(workspaceId)).value ?? const [];
    final canManage = ref
        .watch(myPermissionsProvider)
        .contains(WorkspacePermission.workspaceSettings);
    final open = views.where((v) => v.id == openId).firstOrNull;
    final opened = open == null
        ? null
        : checkView(open.definition, visibleModules).query;
    final modified = open != null && opened != query;
    bool editable(BiSavedView v) =>
        v.scope == BiViewScope.private ? v.mine : canManage;
    final myDefault = views.any(
      (v) => v.scope == BiViewScope.private && v.mine && v.isDefault,
    );
    final teamDefault = views.any(
      (v) => v.scope == BiViewScope.workspace && v.isDefault,
    );

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

    final actions = ref.read(biViewActionsProvider);
    String label(BiSavedView v) => '${v.name}${v.isDefault ? ' ★' : ''}';

    final items = <PopupMenuEntry<void Function()>>[
      PopupMenuItem(
        key: const ValueKey('bi-views-standard'),
        value: () => onOpen(null, BiQueryContext.standard),
        child: Text(l10n?.biViewStandard ?? 'Standard view'),
      ),
      for (final scope in BiViewScope.values)
        if (views.any((v) => v.scope == scope)) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            enabled: false,
            child: Text(
              scope == BiViewScope.private
                  ? l10n?.biViewsMine ?? 'My views'
                  : l10n?.biViewsTeam ?? 'Team views',
            ),
          ),
          for (final v in views.where((v) => v.scope == scope))
            PopupMenuItem(
              key: ValueKey('bi-views-open-${v.id}'),
              value: () {
                final check = checkView(v.definition, visibleModules);
                if (check.query == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n?.biViewUnreadable ??
                            'This view cannot be opened here: it was saved '
                                'in a form this version does not read, or '
                                'none of its analyses is available to you.',
                      ),
                    ),
                  );
                  return;
                }
                onOpen(v, check.query!);
              },
              child: Text(label(v)),
            ),
        ],
      const PopupMenuDivider(),
      if (open != null && editable(open))
        PopupMenuItem(
          key: const ValueKey('bi-views-save'),
          value: () => run(() async {
            final saved = await actions.save(
              workspaceId,
              over: open,
              scope: open.scope,
              name: open.name,
              definition: BiViewDefinition.of(query),
            );
            onOpen(saved, query);
          }),
          child: Text(l10n?.biViewSave ?? 'Save'),
        ),
      PopupMenuItem(
        key: const ValueKey('bi-views-save-as'),
        value: () => run(() async {
          final answer = await showDialog<_SaveAnswer>(
            context: context,
            builder: (_) => _SaveDialog(
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
        child: Text(l10n?.biViewSaveAs ?? 'Save as a new view…'),
      ),
      if (open != null) ...[
        if (editable(open))
          PopupMenuItem(
            key: const ValueKey('bi-views-rename'),
            value: () => run(() async {
              final name = await showDialog<String>(
                context: context,
                builder: (_) => _NameDialog(initial: open.name),
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
            child: Text(l10n?.biViewRename ?? 'Rename…'),
          ),
        PopupMenuItem(
          key: const ValueKey('bi-views-duplicate'),
          value: () => run(() async {
            final copy = await actions.save(
              workspaceId,
              scope: BiViewScope.private,
              name: l10n?.biViewCopyName(open.name) ?? '${open.name} (copy)',
              definition: BiViewDefinition.of(query),
            );
            onOpen(copy, query);
          }),
          child: Text(l10n?.biViewDuplicate ?? 'Duplicate as my view'),
        ),
        if (open.scope == BiViewScope.private && open.mine && !open.isDefault)
          PopupMenuItem(
            key: const ValueKey('bi-views-my-default'),
            value: () => run(
              () =>
                  actions.setDefault(workspaceId, BiViewScope.private, open.id),
            ),
            child: Text(
              l10n?.biViewMakeMyDefault ?? 'Open this view by default',
            ),
          ),
        if (open.scope == BiViewScope.workspace && canManage && !open.isDefault)
          PopupMenuItem(
            key: const ValueKey('bi-views-team-default'),
            value: () => run(
              () => actions.setDefault(
                workspaceId,
                BiViewScope.workspace,
                open.id,
              ),
            ),
            child: Text(
              l10n?.biViewMakeTeamDefault ?? 'Make it the team’s default',
            ),
          ),
        if (editable(open))
          PopupMenuItem(
            key: const ValueKey('bi-views-delete'),
            value: () => run(() async {
              final yes = await showDialog<bool>(
                context: context,
                builder: (dialog) => AlertDialog(
                  content: Text(
                    l10n?.biViewDeleteConfirm(open.name) ??
                        'Delete the view “${open.name}”?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialog).pop(false),
                      child: Text(
                        MaterialLocalizations.of(dialog).cancelButtonLabel,
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('bi-views-delete-confirm'),
                      onPressed: () => Navigator.of(dialog).pop(true),
                      child: Text(l10n?.biViewDelete ?? 'Delete'),
                    ),
                  ],
                ),
              );
              if (yes != true) return;
              await actions.delete(workspaceId, open);
              onOpen(null, query);
            }),
            child: Text(l10n?.biViewDelete ?? 'Delete'),
          ),
      ],
      if (myDefault)
        PopupMenuItem(
          key: const ValueKey('bi-views-clear-my-default'),
          value: () => run(
            () => actions.setDefault(workspaceId, BiViewScope.private, null),
          ),
          child: Text(
            l10n?.biViewClearMyDefault ?? 'Stop opening my default view',
          ),
        ),
      if (teamDefault && canManage)
        PopupMenuItem(
          key: const ValueKey('bi-views-clear-team-default'),
          value: () => run(
            () => actions.setDefault(workspaceId, BiViewScope.workspace, null),
          ),
          child: Text(
            l10n?.biViewClearTeamDefault ?? 'Clear the team’s default',
          ),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        children: [
          PopupMenuButton<void Function()>(
            key: const ValueKey('bi-views'),
            tooltip: l10n?.biViews ?? 'Views',
            itemBuilder: (_) => items,
            onSelected: (action) => action(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bookmarks_outlined),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  open == null
                      ? l10n?.biViewStandard ?? 'Standard view'
                      : label(open),
                  key: const ValueKey('bi-views-current'),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
          if (modified)
            Text(
              l10n?.biViewModified ?? 'changed since it was opened',
              key: const ValueKey('bi-views-modified'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _SaveAnswer {
  const _SaveAnswer(this.name, this.scope, this.query);

  final String name;
  final BiViewScope scope;
  final BiQueryContext query;
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    return AlertDialog(
      content: TextField(
        key: const ValueKey('bi-views-name'),
        controller: _name,
        autofocus: true,
        maxLength: 80,
        decoration: InputDecoration(labelText: l10n?.biViewName ?? 'Name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(material.cancelButtonLabel),
        ),
        TextButton(
          key: const ValueKey('bi-views-name-ok'),
          onPressed: () {
            final name = _name.text.trim();
            if (name.isNotEmpty) Navigator.of(context).pop(name);
          },
          child: Text(material.okButtonLabel),
        ),
      ],
    );
  }
}

class _SaveDialog extends StatefulWidget {
  const _SaveDialog({
    required this.query,
    required this.today,
    required this.canShare,
    required this.initialName,
  });

  final BiQueryContext query;
  final DateTime today;
  final bool canShare;
  final String initialName;

  @override
  State<_SaveDialog> createState() => _SaveDialogState();
}

class _SaveDialogState extends State<_SaveDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  var _scope = BiViewScope.private;
  var _fixed = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final relative = widget.query.period.isRelative;
    final current = widget.query.current(widget.today);
    return AlertDialog(
      title: Text(l10n?.biViewSaveAs ?? 'Save as a new view…'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('bi-views-name'),
              controller: _name,
              autofocus: true,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: l10n?.biViewName ?? 'Name',
              ),
            ),
            if (widget.canShare)
              SegmentedButton<BiViewScope>(
                key: const ValueKey('bi-views-scope'),
                segments: [
                  ButtonSegment(
                    value: BiViewScope.private,
                    label: Text(l10n?.biViewScopePrivate ?? 'Only me'),
                  ),
                  ButtonSegment(
                    value: BiViewScope.workspace,
                    label: Text(l10n?.biViewScopeTeam ?? 'The team'),
                  ),
                ],
                selected: {_scope},
                onSelectionChanged: (s) => setState(() => _scope = s.first),
              ),
            if (relative) ...[
              const SizedBox(height: AppSpacing.sm),
              RadioGroup<bool>(
                groupValue: _fixed,
                onChanged: (v) => setState(() => _fixed = v ?? false),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<bool>(
                      key: const ValueKey('bi-views-period-moves'),
                      value: false,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l10n?.biViewPeriodMoves ??
                            'The period moves with the day it is opened',
                      ),
                    ),
                    RadioListTile<bool>(
                      key: const ValueKey('bi-views-period-fixed'),
                      value: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l10n?.biViewPeriodFixed(
                              biPeriodLabel(current, l10n, locale),
                            ) ??
                            'Always ${biPeriodLabel(current, l10n, locale)}',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(material.cancelButtonLabel),
        ),
        TextButton(
          key: const ValueKey('bi-views-save-ok'),
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(
              _SaveAnswer(
                name,
                _scope,
                _fixed
                    ? widget.query.copyWith(period: BiPeriodRef.fixed(current))
                    : widget.query,
              ),
            );
          },
          child: Text(material.saveButtonLabel),
        ),
      ],
    );
  }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › Home — my spaces, the way I arranged them: in groups that fold
// (Favorites and Other are always there, the rest are mine), searchable and
// sortable, and — in my own order — movable by holding a space for a second.
import 'package:flutter/material.dart';
import '../../workspace/domain/workspace.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/space_prefs_store.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../workspace/domain/member.dart';
import '../../workspace/presentation/member_labels.dart';
import '../../workspace/presentation/widgets/workspace_avatar.dart';
import '../providers/space_prefs_provider.dart';
import 'me_space_card.dart';
import '../../workspace/presentation/widgets/brand_swatch.dart';
import 'me_workspace_row.dart';
import 'space_row_controls.dart';

class MeSpacesList extends ConsumerStatefulWidget {
  const MeSpacesList({
    super.key,
    required this.spaces,
    required this.memberships,
    required this.lastUsedId,
  });

  final List<Workspace> spaces;
  final List<Member> memberships;

  /// The space I entered last (kept for the quiet ring on its card).
  final String? lastUsedId;

  @override
  ConsumerState<MeSpacesList> createState() => _MeSpacesListState();
}

class _MeSpacesListState extends ConsumerState<MeSpacesList> {
  String _query = '';

  Member? _memberOf(Workspace s) =>
      widget.memberships.where((m) => m.workspaceId == s.id).firstOrNull;

  String _groupName(AppLocalizations? l10n, SpacePrefs prefs, String id) =>
      switch (id) {
        SpaceGroup.favoritesGroup => l10n?.meGroupFavorites ?? 'Favorites',
        SpaceGroup.otherGroup => l10n?.meGroupOther ?? 'Other',
        _ => prefs.groups.firstWhere((g) => g.id == id).name,
      };

  Future<String?> _askName(BuildContext context, {String initial = ''}) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n?.meGroupName ?? 'Group name'),
        content: TextField(
          key: const ValueKey('me-group-name-field'),
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.of(dialog).pop(v),
        ),
        actions: [
          TextButton(
            key: const ValueKey('me-group-cancel'),
            onPressed: () => Navigator.of(dialog).pop(),
            child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('me-group-save'),
            onPressed: () => Navigator.of(dialog).pop(controller.text),
            child: Text(l10n?.commonSave ?? 'Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addGroup(BuildContext context, {String? thenMove}) async {
    final name = await _askName(context);
    if (name == null || !mounted) return;
    final notifier = ref.read(spacePrefsProvider.notifier);
    final id = await notifier.addGroup(name);
    if (id != null && thenMove != null) await notifier.moveToGroup(thenMove, id);
  }

  Future<void> _pickGroup(BuildContext context, String key) async {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.read(spacePrefsProvider).value ?? SpacePrefs.empty;
    final current = prefs.groupIdOf(key);
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final id in prefs.groupIds)
              ListTile(
                key: ValueKey('me-group-pick-$id'),
                leading: Icon(
                  id == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(_groupName(l10n, prefs, id)),
                onTap: () => Navigator.of(sheet).pop(id),
              ),
            const Divider(),
            ListTile(
              key: const ValueKey('me-group-pick-new'),
              leading: const Icon(Icons.add),
              title: Text(l10n?.meGroupAdd ?? 'New group'),
              onTap: () => Navigator.of(sheet).pop('\u0000new'),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    if (picked == '\u0000new') {
      await _addGroup(context, thenMove: key);
    } else {
      await ref.read(spacePrefsProvider.notifier).moveToGroup(key, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(spacePrefsProvider).value ?? SpacePrefs.empty;
    final notifier = ref.read(spacePrefsProvider.notifier);
    final byKey = <String, List<Workspace>>{};
    // Unplaced spaces keep the order they come in, the last used one first.
    for (final space in [
      ...widget.spaces.where((w) => w.id == widget.lastUsedId),
      ...widget.spaces.where((w) => w.id != widget.lastUsedId),
    ]) {
      byKey.putIfAbsent(spaceRowKeyOf(space), () => []).add(space);
    }
    String nameOf(String key) => byKey[key]!.first.name;
    final query = _query.trim().toLowerCase();
    final visible = [
      for (final k in byKey.keys)
        if (query.isEmpty || nameOf(k).toLowerCase().contains(query)) k,
    ];
    // Holding a card moves it only in my own order, with nothing filtered.
    final canDrag = prefs.sort == SpaceSort.byHand && query.isEmpty;
    final sections = <Widget>[];
    for (final id in prefs.groupIds) {
      final keys = prefs.sorted([
        for (final k in visible)
          if (prefs.groupIdOf(k) == id) k,
      ], nameOf);
      if (query.isNotEmpty && keys.isEmpty) continue;
      final folded = prefs.folded.contains(id);
      sections.add(
        _GroupHeader(
          id: id,
          title: _groupName(l10n, prefs, id),
          count: keys.length,
          folded: folded,
          own: prefs.groups.any((g) => g.id == id),
          onToggle: () => notifier.toggleFolded(id),
          onRename: () async {
            final name = await _askName(context, initial: _groupName(l10n, prefs, id));
            if (name != null) await notifier.renameGroup(id, name);
          },
          onDelete: () => notifier.removeGroup(id),
        ),
      );
      if (folded) continue;
      if (keys.isEmpty) {
        if (query.isEmpty && id != SpaceGroup.otherGroup) {
          sections.add(
            Padding(
              key: ValueKey('me-group-empty-$id'),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                0,
                AppSpacing.xs,
                AppSpacing.md,
              ),
              child: Text(
                id == SpaceGroup.favoritesGroup
                    ? (l10n?.meGroupEmptyFavorites ??
                          'Give a space a heart and it waits for you here.')
                    : (l10n?.meGroupEmptyOwn ??
                          'Move spaces here from their menu.'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        continue;
      }
      sections.add(
        ReorderableListView.builder(
          key: ValueKey('me-group-list-$id'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: keys.length,
          onReorderItem: (from, to) => notifier.reorder(keys, from, to),
          proxyDecorator: (child, _, animation) => Material(
            color: Colors.transparent,
            elevation: 8,
            borderRadius: AppRadius.xxlAll,
            child: child,
          ),
          itemBuilder: (context, i) =>
              _row(context, prefs, keys, keys[i], byKey[keys[i]]!, canDrag ? i : null),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          sort: prefs.sort,
          onQuery: (v) => setState(() => _query = v),
          onSort: notifier.setSort,
          onAddGroup: () => _addGroup(context),
        ),
        if (query.isNotEmpty && visible.isEmpty)
          Padding(
            key: const ValueKey('me-spaces-no-match'),
            padding: AppSpacing.lgAll,
            child: Text(
              l10n?.meSpacesNoMatch ?? 'No space matches.',
              textAlign: TextAlign.center,
            ),
          ),
        ...sections,
      ],
    );
  }

  Widget _row(
    BuildContext context,
    SpacePrefs prefs,
    List<String> groupKeys,
    String key,
    List<Workspace> group,
    int? dragIndex,
  ) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(spacePrefsProvider.notifier);
    final sides = [...group]
      ..sort((a, b) => b.environment.compareTo(a.environment));
    return MeWorkspaceRow(
      key: ValueKey('me-space-pair-${group.first.pairId.isEmpty ? group.first.id : group.first.pairId}'),
      dragIndex: dragIndex,
      controls: SpaceRowControls(
        rowKey: key,
        name: group.first.name,
        favorite: prefs.favorites.contains(key),
        rating: prefs.ratings[key],
        onFavorite: () => notifier.toggleFavorite(key),
        onRate: (stars) => notifier.rate(key, stars),
        onMoveToGroup: () => _pickGroup(context, key),
        leave: [
          for (final space in sides)
            SpaceLeaveItem(
              id: space.id,
              label: (_memberOf(space)?.isOwner ?? false)
                  ? (l10n?.meLeaveOwner ??
                        'Owners hand the space over before leaving')
                  : group.length == 1
                  ? (l10n?.meLeaveAction ?? 'Leave this space')
                  : (l10n?.meLeaveSide(
                          space.environment == 'prod'
                              ? l10n.profilesPairProd
                              : l10n.profilesPairDev,
                        ) ??
                        'Leave ${space.environment}'),
              enabled: !(_memberOf(space)?.isOwner ?? false),
              onLeave: () =>
                  confirmLeaveSpace(context, ref, space, _memberOf(space)),
            ),
        ],
        onUp: prefs.moved(groupKeys, key, -1) == null
            ? null
            : () => notifier.move(groupKeys, key, -1),
        onDown: prefs.moved(groupKeys, key, 1) == null
            ? null
            : () => notifier.move(groupKeys, key, 1),
      ),
      environmentHint: group.any((s) => s.isDevelopment)
          ? (l10n ?? AppLocalizationsEn()).uxTestSpaceHint
          : null,
      avatar: WorkspaceAvatar(workspace: group.first),
      // #2313 — production's identity when the pair has one.
      brand: spaceBrand(sides.first),
      name: group.first.name,
      lastUsed: group.any((s) => s.id == widget.lastUsedId),
      detail: {
        for (final space in group)
          if (_memberOf(space) case final member?)
            member.status == MemberStatus.pending
                ? (l10n?.meSpacePending ?? 'Waiting for approval')
                : memberRoleLabel(l10n, member),
      }.join(' · '),
      actions: [
        // A space without a production side keeps development at the right.
        if (!group.any((s) => s.environment == 'prod'))
          const Spacer(flex: MeSpaceCard.prodFlex),
        for (final space in sides)
          MeSpaceCard(
            space: space,
            member: _memberOf(space),
            lastUsed: space.id == widget.lastUsedId,
          ),
      ],
    );
  }
}

/// Search, sort and a new group, on one line.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.sort,
    required this.onQuery,
    required this.onSort,
    required this.onAddGroup,
  });
  final SpaceSort sort;
  final ValueChanged<String> onQuery;
  final ValueChanged<SpaceSort> onSort;
  final VoidCallback onAddGroup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String label(SpaceSort s) => switch (s) {
      SpaceSort.byHand => l10n?.meSortHand ?? 'My order',
      SpaceSort.recent => l10n?.meSortRecent ?? 'Recently used',
      SpaceSort.rating => l10n?.meSortRating ?? 'Best rated',
      SpaceSort.alphabet => l10n?.meSortAlphabet ?? 'A–Z',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('me-spaces-search'),
              onChanged: onQuery,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: l10n?.meSpacesSearch ?? 'Search my spaces',
                filled: true,
                border: const OutlineInputBorder(
                  borderRadius: AppRadius.xlAll,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          PopupMenuButton<SpaceSort>(
            key: const ValueKey('me-spaces-sort'),
            tooltip: l10n?.meSortTooltip ?? 'Sort',
            icon: const Icon(Icons.sort),
            style: IconButton.styleFrom(side: BorderSide.none),
            initialValue: sort,
            onSelected: onSort,
            itemBuilder: (_) => [
              for (final s in SpaceSort.values)
                CheckedPopupMenuItem(
                  key: ValueKey('me-spaces-sort-${s.wire}'),
                  value: s,
                  checked: s == sort,
                  child: Text(label(s)),
                ),
            ],
          ),
          IconButton(
            key: const ValueKey('me-spaces-add-group'),
            tooltip: l10n?.meGroupAdd ?? 'New group',
            style: IconButton.styleFrom(side: BorderSide.none),
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: onAddGroup,
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.id,
    required this.title,
    required this.count,
    required this.folded,
    required this.own,
    required this.onToggle,
    required this.onRename,
    required this.onDelete,
  });
  final String id, title;
  final int count;
  final bool folded, own;
  final VoidCallback onToggle, onRename, onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: ValueKey('me-group-$id'),
              borderRadius: AppRadius.mdAll,
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm,
                  horizontal: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: folded ? -0.25 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: const Icon(Icons.expand_more),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    if (id == SpaceGroup.favoritesGroup) ...[
                      Icon(Icons.favorite, size: 16, color: theme.colorScheme.error),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.strong,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '$count',
                      key: ValueKey('me-group-count-$id'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (own)
            PopupMenuButton<String>(
              key: ValueKey('me-group-menu-$id'),
              style: IconButton.styleFrom(side: BorderSide.none),
              onSelected: (v) => v == 'rename' ? onRename() : onDelete(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  key: ValueKey('me-group-rename-$id'),
                  value: 'rename',
                  child: Text(l10n?.meGroupRename ?? 'Rename'),
                ),
                PopupMenuItem(
                  key: ValueKey('me-group-delete-$id'),
                  value: 'delete',
                  child: Text(l10n?.meGroupDelete ?? 'Delete group'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

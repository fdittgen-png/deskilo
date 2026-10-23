// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › Home — my spaces, the way I arranged them: in groups that fold
// (Favorites and Other are always there, the rest are mine), searchable and
// sortable, and — in my own order — movable by holding a space for a second.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_settings.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/storage/space_prefs_store.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/server_label.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/domain/member.dart';
import '../../workspace/domain/workspace.dart';
import '../../workspace/presentation/member_labels.dart';
import '../../workspace/presentation/widgets/brand_swatch.dart';
import '../../workspace/presentation/widgets/workspace_avatar.dart';
import '../application/me_spaces_layout.dart';
import '../providers/space_prefs_provider.dart';
import 'group_name_dialog.dart';
import 'me_space_card.dart';
import 'me_spaces_chrome.dart';
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

/// What the group picker returns: one of the groups, or a new one to name.
sealed class _GroupChoice {
  const _GroupChoice();
}

class _ExistingGroup extends _GroupChoice {
  const _ExistingGroup(this.id);
  final String id;
}

class _NewGroup extends _GroupChoice {
  const _NewGroup();
}

class _MeSpacesListState extends ConsumerState<MeSpacesList> {
  String _query = '';

  Member? _memberOf(Workspace s) =>
      widget.memberships.where((m) => m.workspaceId == s.id).firstOrNull;

  String _groupName(AppLocalizations l10n, SpacePrefs prefs, String id) =>
      switch (id) {
        SpaceGroup.favoritesGroup => l10n.meGroupFavorites,
        SpaceGroup.otherGroup => l10n.meGroupOther,
        _ => prefs.groups.firstWhere((g) => g.id == id).name,
      };

  Future<String?> _askName(BuildContext context, {String initial = ''}) =>
      showDialog<String>(
        context: context,
        builder: (_) => GroupNameDialog(initial: initial),
      );

  Future<void> _addGroup(BuildContext context, {String? thenMove}) async {
    final name = await _askName(context);
    if (name == null || !mounted) return;
    final notifier = ref.read(spacePrefsProvider.notifier);
    final id = await notifier.addGroup(name);
    if (id != null && thenMove != null) await notifier.moveToGroup(thenMove, id);
  }

  Future<void> _pickGroup(BuildContext context, String key) async {
    final l10n = context.l10n;
    final prefs = ref.read(spacePrefsProvider).value ?? SpacePrefs.empty;
    final current = prefs.groupIdOf(key);
    final picked = await showAppSheet<_GroupChoice>(
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
                onTap: () => Navigator.of(sheet).pop(_ExistingGroup(id)),
              ),
            const Divider(),
            ListTile(
              key: const ValueKey('me-group-pick-new'),
              leading: const Icon(Icons.add),
              title: Text(l10n.meGroupAdd),
              onTap: () => Navigator.of(sheet).pop(const _NewGroup()),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    switch (picked) {
      case _NewGroup():
        await _addGroup(context, thenMove: key);
      case _ExistingGroup(:final id):
        await ref.read(spacePrefsProvider.notifier).moveToGroup(key, id);
    }
  }

  /// #2343 — the server these spaces live on: the one this process runs
  /// on (Settings may already hold the next one, pending a restart).
  String? _hostedOn(AppLocalizations l10n) {
    final booted = ref.watch(bootedBackendUrlProvider);
    final url = booted.isNotEmpty
        ? booted
        : ref.watch(activeBackendProvider).value?.url;
    return url == null ? null : serverLabel(l10n, url);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final prefs = ref.watch(spacePrefsProvider).value ?? SpacePrefs.empty;
    final notifier = ref.read(spacePrefsProvider.notifier);
    final layout = MeSpacesLayout.of(
      prefs: prefs,
      spaces: widget.spaces,
      lastUsedId: widget.lastUsedId,
      query: _query,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MeSpacesToolbar(
          sort: prefs.sort,
          onQuery: (v) => setState(() => _query = v),
          onSort: notifier.setSort,
          onAddGroup: () => _addGroup(context),
        ),
        if (layout.noMatch)
          Padding(
            key: const ValueKey('me-spaces-no-match'),
            padding: AppSpacing.lgAll,
            child: Text(
              l10n.meSpacesNoMatch,
              textAlign: TextAlign.center,
            ),
          ),
        for (final group in layout.groups)
          ..._group(context, prefs, layout, group),
      ],
    );
  }

  /// One group: its header, then its rows, why it is empty, or nothing
  /// while it is folded.
  List<Widget> _group(
    BuildContext context,
    SpacePrefs prefs,
    MeSpacesLayout layout,
    SpaceGroupRows group,
  ) {
    final l10n = context.l10n;
    final notifier = ref.read(spacePrefsProvider.notifier);
    final (:id, :keys) = group;
    final folded = prefs.folded.contains(id);
    return [
      MeGroupHeader(
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
      if (!folded && keys.isEmpty && layout.explainsEmpty(id))
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
                ? (l10n.meGroupEmptyFavorites)
                : (l10n.meGroupEmptyOwn),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        )
      else if (!folded && keys.isNotEmpty)
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
          itemBuilder: (context, i) => _row(context, prefs, keys, keys[i],
              layout.rows[keys[i]]!, layout.canDrag ? i : null),
        ),
    ];
  }

  /// How the way out of one side is named: an owner hands over first, a
  /// lone space is left as a whole, a pair names the side.
  String _leaveLabel(
    AppLocalizations l10n,
    Workspace side,
    Member? member,
    int sides,
  ) {
    if (member?.isOwner ?? false) return l10n.meLeaveOwner;
    if (sides == 1) return l10n.meLeaveAction;
    return l10n.meLeaveSide(
      side.env.isProduction ? l10n.profilesPairProd : l10n.profilesPairDev,
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
    final l10n = context.l10n;
    final notifier = ref.read(spacePrefsProvider.notifier);
    final members = [for (final space in group) (space, _memberOf(space))];
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
        hostedOn: _hostedOn(l10n),
        leave: [
          for (final (space, member) in members)
            SpaceLeaveItem(
              id: space.id,
              label: _leaveLabel(l10n, space, member, group.length),
              enabled: !(member?.isOwner ?? false),
              onLeave: () => confirmLeaveSpace(context, ref, space, member),
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
          ? l10n.uxTestSpaceHint
          : null,
      avatar: WorkspaceAvatar(workspace: group.first),
      // #2313 — production's identity when the pair has one.
      brand: spaceBrand(group.first),
      name: group.first.name,
      lastUsed: group.any((s) => s.id == widget.lastUsedId),
      detail: {
        for (final (_, member) in members)
          if (member != null)
            if (member.status == MemberStatus.pending) l10n.meSpacePending else memberRoleLabel(l10n, member),
      }.join(' · '),
      actions: [
        // A space without a production side keeps development at the right.
        if (!group.any((s) => s.env.isProduction))
          const Spacer(flex: MeSpaceCard.prodFlex),
        for (final (space, member) in members)
          MeSpaceCard(
            space: space,
            member: member,
            lastUsed: space.id == widget.lastUsedId,
          ),
      ],
    );
  }
}

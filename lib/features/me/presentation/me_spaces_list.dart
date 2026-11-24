// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Me › Home — my spaces, the way I arranged them: in groups that fold
// (Favorites and Other are always there, the rest are mine), searchable and
// sortable, and — in my own order — movable by holding a space for a second.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_settings.dart';
import '../../../core/i18n/country_names.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/storage/space_prefs_store.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/async_read_body.dart';
import '../../../core/ui/server_label.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/domain/member.dart';
import '../../workspace/domain/workspace.dart';
import '../../workspace/presentation/business_kind_names.dart';
import '../../workspace/presentation/member_labels.dart';
import '../../workspace/presentation/screens/organisation_overview_screen.dart';
import '../../workspace/presentation/widgets/brand_swatch.dart';
import '../../workspace/presentation/widgets/workspace_avatar.dart';
import '../../workspace/providers/my_business_kind_providers.dart';
import '../../workspace/providers/organisation_providers.dart';
import '../application/me_spaces_layout.dart';
import '../providers/space_prefs_provider.dart';
import 'group_name_dialog.dart';
import 'me_other_houses.dart';
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
    // #3749 — the stored layout, or nothing: a picker built on an empty
    // layout would offer no group and move from the wrong one.
    final SpacePrefs prefs;
    try {
      prefs = await ref.read(spacePrefsProvider.future);
    } on Object catch (e, st) {
      TraceLogger.instance.log(TraceLevel.info, 'me', 'me_spaces_list: Object handled', error: e, stackTrace: st);
      return;
    }
    if (!context.mounted) return;
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
    final prefsStandIn = readsStandIn(ref, [spacePrefsProvider]);
    if (prefsStandIn != null) return prefsStandIn;
    final prefs = ref.watch(spacePrefsProvider).requireValue;
    final notifier = ref.read(spacePrefsProvider.notifier);
    final layout = MeSpacesLayout.of(
      prefs: prefs,
      spaces: widget.spaces,
      lastUsedId: widget.lastUsedId,
      query: _query,
      // #4006 — while the organisations are read, or when they cannot be,
      // every business stays where the person put it.
      organisations: ref.watch(myOrganisationsProvider).value ?? const [], // empty-ok: the layout
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
    final (:id, :keys, :organisation) = group;
    final folded = prefs.folded.contains(id);
    // #4006 — an organisation's houses keep the organisation's order.
    final canDrag = layout.canDrag && organisation == null;
    return [
      MeGroupHeader(
        id: id,
        title: organisation ?? _groupName(l10n, prefs, id),
        count: keys.length,
        folded: folded,
        own: prefs.groups.any((g) => g.id == id),
        onToggle: () => notifier.toggleFolded(id),
        onRename: () async {
          final name = await _askName(context, initial: _groupName(l10n, prefs, id));
          if (name != null) await notifier.renameGroup(id, name);
        },
        onDelete: () => notifier.removeGroup(id),
        onOverview: switch (organisationOfGroup(id)) {
          final organisationId? => () =>
              OrganisationOverviewScreen.open(context, organisationId),
          null => null,
        },
      ),
      // #3281: an empty Favorites is only its header; the heart on a space
      // is the way in, no block of explanation is allocated to it.
      if (!folded &&
          keys.isEmpty &&
          id != SpaceGroup.favoritesGroup &&
          layout.explainsEmpty(id))
        Padding(
          key: ValueKey('me-group-empty-$id'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            0,
            AppSpacing.xs,
            AppSpacing.md,
          ),
          child: Text(
            l10n.meGroupEmptyOwn,
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
              layout.rows[keys[i]]!,
              (index: canDrag ? i : null, housed: organisation != null)),
        ),
      // #4008 — the organisation's houses the person may ask to join.
      if (!folded && organisation != null)
        if (organisationOfGroup(id) case final organisationId?)
          MeOtherHouses(organisationId: organisationId),
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
    ({int? index, bool housed}) place,
  ) {
    final (index: dragIndex, :housed) = place;
    final l10n = context.l10n;
    final notifier = ref.read(spacePrefsProvider.notifier);
    final members = [for (final space in group) (space, _memberOf(space))];
    // #4168 — the kind the business set, named; none when it chose none.
    final kind = ref.watch(myBusinessKindsProvider).value?[group.first.id];
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
        // #4006 — a house stays in its organisation, in its order.
        onMoveToGroup: housed ? null : () => _pickGroup(context, key),
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
        onUp: housed || prefs.moved(groupKeys, key, -1) == null
            ? null
            : () => notifier.move(groupKeys, key, -1),
        onDown: housed || prefs.moved(groupKeys, key, 1) == null
            ? null
            : () => notifier.move(groupKeys, key, 1),
      ),
      // #4071 — every row says which kind it is, so a row's height does not
      // depend on whether the business has a test side.
      environmentHint: group.any((s) => s.isDevelopment)
          ? l10n.meTestBusinessHint
          : l10n.uxRealSpaceHint,
      avatar: WorkspaceAvatar(workspace: group.first),
      // #2313 — production's identity when the pair has one.
      brand: spaceBrand(group.first),
      name: group.first.name,
      lastUsed: group.any((s) => s.id == widget.lastUsedId),
      detail: {
        if (kind != null) businessKindLabel(l10n, kind) ?? kind,
        // #4006 — where the business is and what it counts in.
        if (group.first.countryCode.isNotEmpty)
          localizedCountryName(l10n, group.first.countryCode),
        if (group.first.currencyCode.isNotEmpty) group.first.currencyCode,
        for (final (_, member) in members)
          if (member != null)
            if (member.status == MemberStatus.pending) l10n.meSpacePending else memberRoleLabel(l10n, member),
      }.join(' · '),
      actions: [
        // #4131 — side by side while every word fits, else one under the other.
        Expanded(
          child: MeSpaceActions(sides: members, lastUsedId: widget.lastUsedId),
        ),
      ],
    );
  }
}

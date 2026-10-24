// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2554 — Me › My spaces under the personal shell (`/me/spaces`): every
// workspace my account names, read on my personal home
// (`my_personal_workspace_refs_v1`, #2563), each with its host and whether
// its membership is verified there. A failed read is not "no space": it
// says so and offers Try again. A workspace on another installation stays
// listed, honestly unverified, with no Open it could not honour. With no
// space at all, Join and Discover lead and Create follows.
//
// The search filters the loaded records only. Managing this server's spaces
// (default, home site, environments, the platform tools) stays on its own
// page, one tap away (`/me/spaces/manage`).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/space_entry.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/personal_theme.dart';
import '../../../core/time/clock.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/domain/workspace.dart';
import '../../workspace/providers/workspace_host_providers.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/personal_spaces_view.dart';
import '../domain/personal_workspace_refs.dart';
import '../domain/space_pairs.dart';
import '../providers/me_providers.dart';
import '../providers/space_prefs_provider.dart';
import 'create_host_sheet.dart';
import 'me_shell.dart';
import 'personal_refs_section.dart';

/// The page under `/me/spaces` that manages this server's spaces.
const String personalSpacesManagePath = '/me/spaces/manage';

class PersonalSpacesView extends ConsumerStatefulWidget {
  const PersonalSpacesView({super.key});

  @override
  ConsumerState<PersonalSpacesView> createState() => _PersonalSpacesState();
}

class _PersonalSpacesState extends ConsumerState<PersonalSpacesView> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// `refresh`, not `invalidate`: the retry rebuilds on the spot.
  void _retry() =>
      unawaited(ref.refresh(personalWorkspaceRefsProvider.future));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final answer = ref.watch(personalWorkspaceRefsProvider);
    final localAsync = ref.watch(myWorkspacesProvider);
    final local = localAsync.value ?? const <Workspace>[];
    // #1650 — this server's spaces could not be read: entry needs them, so
    // the page says so beside the references it could read.
    final localFailed = localAsync.hasError && !localAsync.hasValue;
    // A failed read is never an empty list; a refresh keeps what was shown.
    final failed = answer.hasError && !answer.isLoading;
    final loaded = failed ? null : answer.value;
    final all = loaded?.refs ?? const <PersonalWorkspaceRef>[];
    final entries = loaded == null
        ? const <PersonalSpaceEntry>[]
        : personalSpaceEntries(loaded, local, query: _query);
    final hostsHere = all.any((r) => r.hostedHere && r.status != null);
    final theme = Theme.of(context);
    final tokens = PersonalTheme.of(context);

    final children = <Widget>[
      Row(
        children: [
          Expanded(
            child: Text(
              l10n.meMySpaces,
              style: theme.textTheme.titleLarge?.strong,
            ),
          ),
          if (loaded != null)
            Text(
              l10n.mySpacesCount(all.length),
              key: const ValueKey('my-spaces-count'),
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: tokens.secondaryText),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      if (localFailed) ...[
        InlineBanner(
          key: const ValueKey('my-spaces-local-unavailable'),
          icon: Icons.cloud_off_outlined,
          text: l10n.profilesUnavailable,
          actionLabel: l10n.commonRetry,
          onAction: () => unawaited(ref.refresh(myWorkspacesProvider.future)),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      if (failed)
        InlineBanner(
          key: const ValueKey('my-spaces-unavailable'),
          icon: Icons.cloud_off_outlined,
          text: l10n.mySpacesUnavailable,
          actionLabel: l10n.commonRetry,
          onAction: _retry,
        )
      else if (loaded == null)
        const LinearProgressIndicator(key: ValueKey('my-spaces-loading'))
      else if (all.isEmpty)
        EmptyState(
          key: const ValueKey('my-spaces-empty'),
          icon: Icons.meeting_room_outlined,
          title: l10n.meNoSpaceTitle,
          subtitle: l10n.meNoSpaceBody,
        )
      else ...[
        AppTextField(
          key: const ValueKey('my-spaces-search'),
          controller: _search,
          label: l10n.meSpacesSearch,
          textInputAction: TextInputAction.search,
          onChanged: (q) => setState(() => _query = q),
        ),
        const SizedBox(height: AppSpacing.md),
        if (entries.isEmpty)
          Padding(
            key: const ValueKey('my-spaces-no-match'),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text(l10n.mySpacesNoMatch,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: tokens.secondaryText)),
          ),
      ],
    ];

    final footer = <Widget>[
      const SizedBox(height: AppSpacing.lg),
      _Actions(empty: loaded != null && all.isEmpty),
      if (hostsHere)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const ValueKey('my-spaces-manage'),
            style: TextButton.styleFrom(
                minimumSize: const Size(0, PersonalShellMetrics.minTarget)),
            onPressed: () => context.push(personalSpacesManagePath),
            child: Text(l10n.mySpacesManage),
          ),
        ),
      const SizedBox(height: AppSpacing.xl),
    ];

    return Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView.builder(
            key: const ValueKey('my-spaces-list'),
            padding: AppSpacing.gutterAll,
            itemCount: children.length + entries.length + footer.length,
            itemBuilder: (context, i) {
              if (i < children.length) return children[i];
              final e = i - children.length;
              if (e < entries.length) {
                return _SpaceCard(entry: entries[e], l10n: l10n);
              }
              return footer[e - entries.length];
            },
          ),
        ),
      ),
    );
  }
}

/// One space: its name, host and verification, and the one action its
/// state allows. The card is not a button: its action is.
class _SpaceCard extends ConsumerWidget {
  const _SpaceCard({required this.entry, required this.l10n});

  final PersonalSpaceEntry entry;
  final AppLocalizations l10n;

  String _host() => entry.host == PersonalSpaceHost.here
      ? l10n.mySpacesHostHere
      : l10n.mySpacesHostElsewhere;

  String _state() => [
        if (entry.verified) l10n.mySpacesVerified,
        PersonalRefsSection.detail(l10n, entry.ref),
        if (entry.isTest) l10n.mySpacesTestSpace,
      ].join(' · ');

  void _open(BuildContext context, WidgetRef ref, Workspace space) {
    // The "recently used" sort remembers when I went in.
    unawaited(ref
        .read(spacePrefsProvider.notifier)
        .touch(spaceRowKeyOf(space), ref.read(clockProvider).now()));
    unawaited(enterSpace(context, ref, space));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = PersonalTheme.of(context);
    final theme = Theme.of(context);
    final id = entry.ref.networkId;
    final unverified = entry.ref.freshness == RefFreshness.unavailable;
    final local = entry.local;
    final Widget? action = switch (entry.action) {
      PersonalSpaceAction.open when local != null => FilledButton.tonal(
          key: ValueKey('my-space-open-$id'),
          style: FilledButton.styleFrom(
              minimumSize: const Size(0, PersonalShellMetrics.minTarget)),
          onPressed: () => _open(context, ref, local),
          child: Text(
              entry.isTest ? l10n.mySpacesOpenTest : l10n.mySpacesOpen),
        ),
      PersonalSpaceAction.requestStatus => OutlinedButton(
          key: ValueKey('my-space-request-$id'),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, PersonalShellMetrics.minTarget)),
          onPressed: () => context.push('/applications'),
          child: Text(l10n.mySpacesRequestStatus),
        ),
      _ => null,
    };
    return Card(
      key: ValueKey('my-space-$id'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: PersonalShellMetrics.cardRadiusAll,
        side: BorderSide(color: tokens.decorativeBorder),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  unverified
                      ? Icons.cloud_off_outlined
                      : Icons.meeting_room_outlined,
                  color: tokens.secondaryText,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    entry.ref.label ?? l10n.meRefUnnamed,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.strong,
                  ),
                ),
                if (entry.ref.isFavorite)
                  Icon(Icons.star,
                      color: tokens.primary,
                      semanticLabel: l10n.meGroupFavorites),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _host(),
              key: ValueKey('my-space-host-$id'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: tokens.secondaryText),
            ),
            Text(
              _state(),
              key: ValueKey('my-space-state-$id'),
              style: theme.textTheme.bodySmall?.copyWith(
                  color: unverified ? tokens.warning : tokens.secondaryText),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(alignment: AlignmentDirectional.centerEnd, child: action),
            ],
          ],
        ),
      ),
    );
  }
}

/// Join and Discover lead while there is no space; Create follows.
class _Actions extends ConsumerWidget {
  const _Actions({required this.empty});

  final bool empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // #2562 C2c -- read ahead, so Create knows whether there is a choice.
    ref.watch(workspaceHostsProvider);
    const target = Size(0, PersonalShellMetrics.minTarget);
    final join = empty
        ? FilledButton.icon(
            key: const ValueKey('my-spaces-join'),
            style: FilledButton.styleFrom(minimumSize: target),
            icon: const Icon(Icons.qr_code_2_outlined),
            label: Text(l10n.meJoinSpace),
            onPressed: () => context.push('/onboarding?join=1'),
          )
        : OutlinedButton.icon(
            key: const ValueKey('my-spaces-join'),
            style: OutlinedButton.styleFrom(minimumSize: target),
            icon: const Icon(Icons.qr_code_2_outlined),
            label: Text(l10n.meJoinSpace),
            onPressed: () => context.push('/onboarding?join=1'),
          );
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        join,
        OutlinedButton.icon(
          key: const ValueKey('my-spaces-discover'),
          style: OutlinedButton.styleFrom(minimumSize: target),
          icon: const Icon(Icons.travel_explore_outlined),
          label: Text(l10n.mySpacesDiscover),
          onPressed: () => context.go(MeTab.discover.path),
        ),
        TextButton.icon(
          key: const ValueKey('my-spaces-create'),
          style: TextButton.styleFrom(minimumSize: target),
          icon: const Icon(Icons.add_business_outlined),
          label: Text(l10n.meCreateSpace),
          onPressed: () => unawaited(CreateHostSheet.start(context, ref)),
        ),
      ],
    );
  }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2085 — "What you can do here".
//
// Everyone in a workspace is a member, and what they can do beyond that
// comes from their roles. This screen lists it, grouped by where it comes
// from, so a person who was given a role can see what it gave them, and
// whoever gives roles can see what a member holds. It is built by
// `accessSources`, the same pieces `effectivePermissions` adds up, so it
// cannot promise more than the gates grant.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../domain/access_summary.dart';
import '../../domain/member.dart';
import '../../domain/workspace_permission.dart';
import '../../domain/workspace_role.dart';
import '../../providers/workspace_providers.dart';
import '../../providers/workspace_roles_providers.dart';
import 'roles_screen_labels.dart';

class WhatYouCanDoScreen extends ConsumerWidget {
  const WhatYouCanDoScreen({super.key, this.memberId});

  /// Another member, for someone who administers members or roles; null
  /// (or anybody else asking) reads their own.
  final String? memberId;

  static Key sourceKeyFor(AccessSourceKind kind, [String roleKey = '']) =>
      ValueKey('what-you-can-do-${kind.name}$roleKey');

  String _heading(AppLocalizations? l10n, AccessSource source, String locale) =>
      switch (source.kind) {
        AccessSourceKind.owner =>
          l10n?.whatYouCanDoFromOwner ?? 'As the owner: everything',
        AccessSourceKind.coOwner => l10n?.whatYouCanDoFromCoOwner ?? 'As co-owner',
        AccessSourceKind.administrator =>
          l10n?.whatYouCanDoFromAdministrator ?? 'From the Administrator role',
        AccessSourceKind.everyMember =>
          l10n?.whatYouCanDoFromEveryMember ?? 'As every member',
        AccessSourceKind.role => () {
            final name = source.role?.nameIn(locale) ?? '';
            return l10n?.whatYouCanDoFromRole(name) ?? 'From the role $name';
          }(),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(myMemberProvider).value;
    final perms = ref.watch(myPermissionsProvider);
    final members = ref.watch(workspaceMembersProvider);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final roles =
        ref.watch(workspaceRolesProvider).value ?? const <WorkspaceRole>[];
    final assignments = ref.watch(workspaceRoleAssignmentsProvider).value ??
        const <String, Set<String>>{};
    final names =
        ref.watch(memberNamesProvider).value ?? const <String, String>{};
    final locale = Localizations.localeOf(context).languageCode;

    // Somebody else's page only for whoever administers members or roles.
    final mayReadOthers = (me?.canAdminister ?? false) ||
        perms.contains(WorkspacePermission.manageRoles);
    final otherId =
        memberId != null && memberId != me?.id && mayReadOthers ? memberId : null;
    final Member? subject = otherId == null
        ? me
        : members.value?.where((m) => m.id == otherId).firstOrNull;

    final title = otherId == null
        ? (l10n?.whatYouCanDoTitle ?? 'What you can do here')
        : () {
            final name = names[otherId] ?? '';
            return l10n?.whatTheyCanDoTitle(name) ?? 'What $name can do here';
          }();

    if (subject == null) {
      return Scaffold(appBar: AppBar(title: Text(title)), body: const LoadingView());
    }
    final sources = accessSources(
      member: subject,
      workspace: workspace,
      roles: roles,
      heldRoleIds: assignments[subject.id] ?? const <String>{},
    );
    final nothingMore = grantedBy(sources).isEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: AppSpacing.lgAll,
        children: [
          Text(
            l10n?.whatYouCanDoIntro ??
                'Everyone here is a member: booking, checking in, messages '
                    'and your own account. Roles add the rest.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (nothingMore)
            Text(
              l10n?.whatYouCanDoNothingMore ?? 'Nothing more than a member.',
              style: theme.textTheme.titleSmall,
            ),
          for (final source in sources)
            if (source.permissions.isNotEmpty)
              Card(
                key: sourceKeyFor(source.kind, source.role?.key ?? ''),
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Padding(
                  padding: AppSpacing.lgAll,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _heading(l10n, source, locale),
                        style: theme.textTheme.titleSmall,
                      ),
                      // The owner holds the whole catalogue: the heading
                      // says so, and twenty-four lines would say it again.
                      if (source.kind != AccessSourceKind.owner)
                        for (final p in WorkspacePermission.values)
                          if (source.permissions.contains(p))
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: AppSpacing.sm),
                              child: Row(
                                children: [
                                  Icon(Icons.check,
                                      size: 18,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(permissionLabel(l10n, p)),
                                  ),
                                ],
                              ),
                            ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2085 — the members holding a role, in that role's editor.
//
// The second place a role is given (the first is the member's page). It
// asks the same questions as the member page, through the same rules and
// the same command, so the two places cannot disagree about who may give
// what: nobody gives a role to themselves, and a person who is not the
// owner gives only a role whose permissions they hold.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../application/assign_role.dart';
import '../../domain/member.dart';
import '../../domain/role_assignment.dart';
import '../../domain/workspace_role.dart';
import '../../providers/workspace_providers.dart';
import '../../providers/workspace_roles_providers.dart';
import '../../../task_recorder/domain/action_registry.dart';
import '../../../task_recorder/presentation/recorder_seam.dart';

class RoleHoldersSection extends ConsumerWidget {
  const RoleHoldersSection({
    super.key,
    required this.role,
    this.readOnly = false,
  });

  final WorkspaceRole role;

  /// #2085 — the Administrator lists its holders here, but is given and
  /// taken back on the member's page, through the validation quorum.
  final bool readOnly;

  static const Key addKey = Key('role-holders-add');
  static Key holderKeyFor(String memberId) =>
      ValueKey('role-holder-$memberId');

  Future<void> _set(
    BuildContext context,
    WidgetRef ref,
    String memberId, {
    required bool assign,
  }) async {
    final l10n = AppLocalizations.of(context);
    final attempt = recordTaskAttempt(ref, RecorderActions.giveRole,
        payload: {'switch_to': assign ? 'on' : 'off'}); // #1884 B
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: assign ? 'role grant failed' : 'role take-back failed',
      errorText: assign
          ? (l10n?.roleGiveFailed ?? 'The role was not given.')
          : (l10n?.roleTakeBackFailed ?? 'The role was not taken back.'),
      action: () => observeTaskSetting(
          attempt,
          () => setMemberRole(ref,
              memberId: memberId, roleId: role.id, assign: assign)),
    );
    if (!ok || !context.mounted) return;
    AppSnack.success(
      context,
      assign
          ? (l10n?.roleGiven ?? 'Role given.')
          : (l10n?.roleTakenBack ?? 'Role taken back.'),
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    List<Member> candidates,
    Map<String, String> names,
  ) async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(
          AppLocalizations.of(dialogContext)?.roleHoldersAdd ?? 'Add a member',
        ),
        children: [
          for (final m in candidates)
            SimpleDialogOption(
              key: ValueKey('role-holder-pick-${m.id}'),
              onPressed: () => Navigator.of(dialogContext).pop(m.id),
              child: Text(names[m.id] ?? ''),
            ),
        ],
      ),
    );
    if (chosen == null || !context.mounted) return;
    await _set(context, ref, chosen, assign: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(myMemberProvider).value;
    final perms = ref.watch(myPermissionsProvider);
    final members = ref.watch(workspaceMembersProvider).value ?? const <Member>[];
    final names =
        ref.watch(memberNamesProvider).value ?? const <String, String>{};
    final holderIds = ref.watch(roleMembersProvider(role.id)).value ??
        const <String>[];
    final byId = {for (final m in members) m.id: m};

    RoleRefusal? refusal(Member subject, {required bool granting}) =>
        me == null
            ? RoleRefusal.notPermitted
            : customRoleRefusal(
                caller: me,
                callerPermissions: perms,
                subject: subject,
                role: role,
                granting: granting,
              );

    final holders = [
      for (final id in holderIds) ?byId[id],
    ];
    final candidates = [
      for (final m in members)
        if (!holderIds.contains(m.id) && refusal(m, granting: true) == null) m,
    ]..sort((a, b) => (names[a.id] ?? '').compareTo(names[b.id] ?? ''));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n?.roleEditorHolders ?? 'Members in this role',
          style: theme.textTheme.labelLarge,
        ),
        if (holders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(l10n?.roleEditorNobody ?? 'Nobody yet.'),
          ),
        for (final m in holders)
          ListTile(
            key: holderKeyFor(m.id),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(names[m.id] ?? ''),
            trailing: !readOnly && refusal(m, granting: false) == null
                ? IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: MaterialLocalizations.of(context)
                        .deleteButtonTooltip,
                    onPressed: () => _set(context, ref, m.id, assign: false),
                  )
                : null,
          ),
        if (!readOnly && candidates.isNotEmpty && role.active)
          TextButton.icon(
            key: addKey,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: Text(l10n?.roleHoldersAdd ?? 'Add a member'),
            onPressed: () => _pick(context, ref, candidates, names),
          ),
      ],
    );
  }
}

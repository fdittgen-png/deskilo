// SPDX-License-Identifier: 0BSD
//
// #914 — who may administer THIS managed profile.
//
// A managed profile holds a real person's identity before that person
// has an account. Until now any admin of the workspace could read it,
// edit it and hand it over; where several people hold the role, that is
// more exposure than the person agreed to.
//
// The rule names roles, people, or both. Nothing here GRANTS anything —
// `can_manage_managed_profile` (0161) decides, in the database. This is
// how the rule is read and written, and the server refuses a change from
// anyone the rule does not already name, except the workspace owner, who
// may always change a rule so a profile can never become unadministrable.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/managed_access.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/providers/workspace_providers.dart';

class ManagedAccessEditor extends ConsumerWidget {
  const ManagedAccessEditor({super.key, required this.member});

  final Member member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final access = ManagedAccess.fromJson(member.managedAccess);
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final everyone = (ref.watch(workspaceMembersProvider).value ?? const [])
        .where((m) => !m.isManaged && m.id != member.id)
        .toList();

    Future<void> save(ManagedAccess next) async {
      final saved = await runGuarded(
        context,
        domain: 'workspace',
        message: 'managed access change failed',
        errorText: l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
        action: () => ref
            .read(workspaceRepositoryProvider)
            .setManagedAccess(member.id, next),
      );
      ref.invalidate(workspaceMembersProvider);
      if (!saved || !context.mounted) return;
      AppSnack.success(context, l10n?.managedAccessSaved ?? 'Rule saved.');
    }

    return Column(
      key: const ValueKey('managed-access-editor'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(l10n?.managedAccessTitle ?? 'Who may administer this profile',
            style: theme.textTheme.titleSmall),
        Text(
          l10n?.managedAccessHint ??
              'By default: every owner and every admin. The owner may '
                  'always change this rule but only reaches the data when '
                  'the rule names them.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (access.isDefault)
          Text(l10n?.managedAccessDefault ?? 'Every owner and every admin',
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            FilterChip(
              key: const ValueKey('managed-access-owners'),
              label: Text(l10n?.managedAccessOwners ?? 'Owners'),
              selected: access.hasRole(ManagedAccess.roleOwner),
              onSelected: (on) =>
                  save(access.withRole(ManagedAccess.roleOwner, on)),
            ),
            FilterChip(
              key: const ValueKey('managed-access-admins'),
              label: Text(l10n?.managedAccessAdmins ?? 'Admins'),
              selected: access.hasRole(ManagedAccess.roleAdmin),
              onSelected: (on) =>
                  save(access.withRole(ManagedAccess.roleAdmin, on)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n?.managedAccessPeople ?? 'Named people',
            style: theme.textTheme.labelMedium),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final m in everyone)
              FilterChip(
                key: ValueKey('managed-access-member-${m.id}'),
                label: Text(names[m.id] ?? m.id),
                selected: access.memberIds.contains(m.id),
                onSelected: (on) => save(access.withMember(m.id, on)),
              ),
          ],
        ),
      ],
    );
  }
}

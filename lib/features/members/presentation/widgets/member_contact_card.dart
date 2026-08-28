// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/directory_providers.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../../workspace/providers/workspace_providers.dart';

/// HOW TO REACH THIS PERSON, and what the workspace knows about them —
/// as much of it as the viewer is allowed to see (#704).
///
/// THE AUDIENCE DECIDES THE CONTENT, and there are three of them:
///
///  * **yourself** — everything, because it is yours;
///  * **an admin** (`manageMembers`) — the e-mail address and the
///    membership facts they administer: since when, what plan share,
///    what the membership status is;
///  * **anyone else** — the opt-in WhatsApp number and nothing more.
///    Member-to-member contact in this app has always been opt-in, and a
///    profile screen is not a reason to widen it.
///
/// The e-mail rule is not invented here: `memberEmails` hands a plain
/// member an empty map and the server agrees, so a non-admin cannot
/// render an address it never received. What this widget adds is the
/// place to put it and the rule about who gets the rest.
class MemberContactCard extends ConsumerWidget {
  const MemberContactCard({
    super.key,
    required this.member,
    required this.isSelf,
  });

  final Member member;
  final bool isSelf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final permissions = ref.watch(myPermissionsProvider);
    final isAdmin =
        permissions.contains(WorkspacePermission.manageMembers);
    final profile = ref.watch(memberProfilesProvider).value?[member.userId];
    // Admin-only at the source: for anybody else this map is empty.
    final email = ref.watch(memberEmailsProvider).value?[member.id] ?? '';
    final phone = profile?.whatsapp ?? '';

    final rows = <(IconData, String)>[
      if (email.isNotEmpty) (Icons.mail_outline, email),
      if (phone.isNotEmpty) (Icons.chat_outlined, phone),
      // Membership facts, for the people who administer them. The plan
      // share is what a fee conversation starts from, and it is nowhere
      // else on this sheet.
      if (isSelf || isAdmin)
        (
          Icons.pie_chart_outline,
          l10n?.memberPlanShare('${member.subscriptionPct}') ??
              'Plan ${member.subscriptionPct}%',
        ),
      if ((isSelf || isAdmin) && member.status != MemberStatus.active)
        (Icons.pause_circle_outline, _statusLabel(l10n, member.status)),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      key: const ValueKey('member-contact'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 2),
          child: Text(
            (l10n?.memberContactHeading ?? 'Contact').toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.1,
            ),
          ),
        ),
        for (final (icon, text) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SelectableText(
                  text,
                  maxLines: 1,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ]),
          ),
      ],
    );
  }

  String _statusLabel(AppLocalizations? l10n, MemberStatus status) =>
      switch (status) {
        MemberStatus.pending => l10n?.memberStatusPending ?? 'Pending',
        MemberStatus.paused => l10n?.memberStatusPaused ?? 'Paused',
        MemberStatus.exited => l10n?.memberStatusExited ?? 'Exited',
        MemberStatus.active => '',
      };
}

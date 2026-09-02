// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_dot.dart';
import '../../../core/locale/report_language.dart';
import '../../../core/share/file_sharer.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../../events/providers/event_providers.dart';
import '../../members/providers/directory_providers.dart';
import '../../money/presentation/invoice_actions.dart';
import '../../money/providers/money_providers.dart';
import '../domain/member.dart';
import '../domain/overage_policy.dart';
import '../providers/workspace_providers.dart';
import 'widgets/badge_manager_dialog.dart';

/// The admin actions on ONE member (#825) — subscription, overage
/// policy, limits, roles, co-ownership, kiosk, pause, join decisions,
/// badges, the agreement — as top-level functions, so the member page
/// and the Members & plans screen run the SAME code with the same
/// guards, dialogs and invalidations. Each takes the screen's context
/// and ref; each is a no-op when the pick is cancelled or unchanged.

Future<void> pickMemberSubscription(
  BuildContext context,
  WidgetRef ref,
  Member member,
) async {
  final l10n = AppLocalizations.of(context);
  final offered =
      (await ref.read(subscriptionLevelsProvider.future)).offeredLevels;
  if (!context.mounted) return;

  final custom = TextEditingController();
  final pct = await showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n?.memberSubscriptionLabel ?? 'Subscription'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final level in offered)
                ChoiceChip(
                  label: Text(l10n?.percentValue(level) ?? '$level%'),
                  selected: member.subscriptionPct == level,
                  onSelected: (_) => Navigator.of(context).pop(level),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // The owner may always negotiate a free value, even when
          // allow_custom hides it from member-facing pickers.
          TextField(
            controller: custom,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n?.memberSubscriptionCustom ?? 'Custom (1–100)',
              suffixIcon: HelpDot(
                  l10n?.helpHintMembersTopic ?? 'Members & plans'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = int.tryParse(custom.text.trim());
            if (value == null || value < 1 || value > 100) return;
            Navigator.of(context).pop(value);
          },
          child: Text(l10n?.commonSave ?? 'Save'),
        ),
      ],
    ),
  );
  if (pct == null || pct == member.subscriptionPct) return;
  if (!context.mounted) return;

  if (!await runGuarded(
    context,
    domain: 'workspace',
    message: 'member subscription update failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () async {
        await ref
            .read(workspaceRepositoryProvider)
            .updateMemberSubscription(member.id, pct);
    },
  )) {
    return;
  }
  ref.invalidate(workspaceMembersProvider);
}

/// Sets how the member is treated once they have used their whole
/// monthly entitlement (migration 0041): block, pay-as-you-go, or buy a
/// pre-defined day package (0042).
Future<void> pickMemberOveragePolicy(
  BuildContext context,
  WidgetRef ref,
  Member member,
) async {
  final l10n = AppLocalizations.of(context);
  final options = <(OveragePolicy, String)>[
    (
      OveragePolicy.blocked,
      l10n?.overagePolicyBlocked ?? 'Block further booking'
    ),
    (
      OveragePolicy.payg,
      l10n?.overagePolicyPayg ?? 'Charge overage (pay-as-you-go)'
    ),
    (
      OveragePolicy.package,
      l10n?.overagePolicyPackage ?? 'Require buying a package'
    ),
  ];
  final chosen = await showDialog<OveragePolicy>(
    context: context,
    builder: (context) => SimpleDialog(
      title: HelpDotTitle(
        l10n?.memberOveragePolicyLabel ?? 'When days run out',
        l10n?.helpHintMembersTopic ?? 'Members & plans',
      ),
      children: [
        for (final (policy, label) in options)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(policy),
            child: Row(
              children: [
                Icon(
                  member.overagePolicy == policy
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(label)),
              ],
            ),
          ),
      ],
    ),
  );
  if (chosen == null || chosen == member.overagePolicy) return;
  if (!context.mounted) return;

  if (!await runGuarded(
    context,
    domain: 'workspace',
    message: 'member overage policy update failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () async {
        await ref
            .read(workspaceRepositoryProvider)
            .updateMemberOveragePolicy(member.id, chosen);
    },
  )) {
    return;
  }
  ref.invalidate(workspaceMembersProvider);
}

/// #494 — builds THIS member's financial agreement through the report
/// engine and hands the PDF to the share sheet.
Future<void> sendMemberAgreement(
  BuildContext context,
  WidgetRef ref,
  Member member,
  String name,
) async {
  final l10n = AppLocalizations.of(context);
  await runGuarded(
    context,
    domain: 'workspace',
    message: 'agreement share failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () async {
      await warmLetterDocProviders(ref, 'agreement');
      if (!context.mounted) return;
      // #496 — the agreement prints in the MEMBER's language.
      final profile =
          ref.read(memberProfilesProvider).value?[member.userId];
      final String language;
      try {
        language = resolveMemberReportLanguage(ref,
            memberLocale: profile?.preferredLocale ?? '');
      } on AmbiguousReportLanguage {
        AppSnack.error(
          context,
          l10n?.reportLanguageAmbiguous ??
              'This country has several languages — set the '
                  'workspace language in Workspace settings first.',
        );
        return;
      }
      final docL10n = l10nForLanguage(language);
      final data = agreementReportData(context, ref,
          memberName: name,
          subscriptionPct: member.subscriptionPct,
          l10nOverride: docL10n,
          localeName: language);
      final report = renderLetterDoc(context, ref,
          docId: 'agreement', data: data, language: language);
      final pdf = await letterDocPdf(context, ref,
          report: report,
          title: '${docL10n.reportDocAgreement} $name');
      await ref.read(fileSharerProvider)(
        bytes: pdf.bytes,
        fileName: pdf.fileName,
        mimeType: 'application/pdf',
      );
    },
  );
}

/// The kiosk account reverting ITSELF (0056) from its own member row —
/// the same self RPC the Settings tile uses.
Future<void> revertMyKiosk(
  BuildContext context,
  WidgetRef ref,
  Member member,
) async {
  final l10n = AppLocalizations.of(context);
  if (!await runGuarded(
    context,
    domain: 'workspace',
    message: 'kiosk self-revert failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () => ref
        .read(workspaceRepositoryProvider)
        .unsetMyKiosk(member.workspaceId),
  )) {
    return;
  }
  ref
    ..invalidate(workspaceMembersProvider)
    ..invalidate(myMemberProvider);
}

/// Picks the member's co-ownership flavor (0058).
Future<void> pickMemberCoOwner(
  BuildContext context,
  WidgetRef ref,
  Member member,
) async {
  final l10n = AppLocalizations.of(context);
  final options = <(CoOwnerStatus, String)>[
    (CoOwnerStatus.none, l10n?.coOwnerNone ?? 'No co-owner role'),
    (
      CoOwnerStatus.active,
      l10n?.coOwnerActive ??
          'Active co-owner — owner permissions now, automatic succession'
    ),
    (
      CoOwnerStatus.passive,
      l10n?.coOwnerPassive ??
          'Passive co-owner — becomes owner when activated or when the '
              'owner leaves'
    ),
  ];
  final chosen = await showDialog<CoOwnerStatus>(
    context: context,
    builder: (context) => SimpleDialog(
      title: HelpDotTitle(
        l10n?.coOwnerAction ?? 'Co-ownership',
        l10n?.helpHintMembersTopic ?? 'Members & plans',
      ),
      children: [
        for (final (status, label) in options)
          SimpleDialogOption(
            key: ValueKey('co-owner-${status.name}'),
            onPressed: () => Navigator.of(context).pop(status),
            child: Row(
              children: [
                Icon(
                  member.coOwner == status
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(label)),
              ],
            ),
          ),
      ],
    ),
  );
  if (chosen == null || chosen == member.coOwner) return;
  if (!context.mounted) return;
  if (!await runGuarded(
    context,
    domain: 'workspace',
    message: 'co-owner update failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () =>
        ref.read(workspaceRepositoryProvider).setCoOwner(member.id, chosen),
  )) {
    return;
  }
  ref
    ..invalidate(workspaceMembersProvider)
    ..invalidate(myMemberProvider);
}

/// Promotes a co-owner to FULL owner right now (0058).
Future<void> activateMemberCoOwner(
  BuildContext context,
  WidgetRef ref,
  Member member,
) async {
  final l10n = AppLocalizations.of(context);
  if (!await runGuarded(
    context,
    domain: 'workspace',
    message: 'co-owner activation failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () =>
        ref.read(workspaceRepositoryProvider).activateCoOwner(member.id),
  )) {
    return;
  }
  ref
    ..invalidate(workspaceMembersProvider)
    ..invalidate(myMemberProvider);
}

Future<void> toggleMemberPaused(
  BuildContext context,
  WidgetRef ref,
  Member member,
) async {
  final l10n = AppLocalizations.of(context);
  final paused = member.status == MemberStatus.paused;
  if (!await runGuarded(
    context,
    domain: 'workspace',
    message: 'member status update failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () => ref.read(workspaceRepositoryProvider).updateMemberStatus(
          member.id,
          paused ? MemberStatus.active : MemberStatus.paused,
        ),
  )) {
    return;
  }
  ref.invalidate(workspaceMembersProvider);
}

/// Caps [member]'s simultaneous open reservations (0044). Presets plus
/// a custom count and a no-limit reset; the server refuses self-setting
/// (the UI hides the button on the own row anyway).
Future<void> pickMemberReservationLimit(
  BuildContext context,
  WidgetRef ref,
  Member member,
) async {
  final l10n = AppLocalizations.of(context);
  const presets = [1, 2, 3, 5, 10];
  const noLimitSentinel = -1;
  final custom = TextEditingController();
  final chosen = await showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        l10n?.memberReservationLimitLabel ?? 'Reservation limit',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n?.memberReservationLimitExplainer ??
                'How many open reservations this member may hold at '
                    'the same time.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: Text(
                  l10n?.memberReservationLimitNone ?? 'No limit',
                ),
                selected: member.maxActiveReservations == null,
                onSelected: (_) =>
                    Navigator.of(context).pop(noLimitSentinel),
              ),
              for (final preset in presets)
                ChoiceChip(
                  label: Text(preset.toString()),
                  selected: member.maxActiveReservations == preset,
                  onSelected: (_) => Navigator.of(context).pop(preset),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: custom,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n?.memberReservationLimitCustom ??
                  'Custom (1\u2013100)',
              suffixIcon: HelpDot(
                  l10n?.helpHintMembersTopic ?? 'Members & plans'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = int.tryParse(custom.text.trim());
            if (value == null || value < 1 || value > 100) return;
            Navigator.of(context).pop(value);
          },
          child: Text(l10n?.commonSave ?? 'Save'),
        ),
      ],
    ),
  );
  if (chosen == null || !context.mounted) return;
  final limit = chosen == noLimitSentinel ? null : chosen;
  if (limit == member.maxActiveReservations) return;

  if (!await runGuarded(
    context,
    domain: 'workspace',
    message: 'reservation limit update failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () => ref
        .read(workspaceRepositoryProvider)
        .setMemberReservationLimit(member.id, limit),
  )) {
    return;
  }
  ref.invalidate(workspaceMembersProvider);
}

/// #628 (migration 0119) — how many OVERLAPPING bookings [member] may
/// hold. Presets plus a workspace-default reset; the server refuses
/// self-setting exactly like the 0044 cap above.
Future<void> pickMemberSimultaneousLimit(
  BuildContext context,
  WidgetRef ref,
  Member member,
) async {
  final l10n = AppLocalizations.of(context);
  const presets = [1, 2, 3, 5];
  const defaultSentinel = -1;
  final chosen = await showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: HelpDotTitle(
        l10n?.memberSimultaneousLimitLabel ?? 'Simultaneous reservations',
        l10n?.helpHintMembersTopic ?? 'Members & plans',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n?.memberSimultaneousLimitExplainer ??
                'How many bookings this member may hold over the same '
                    'period. Unset follows the workspace default.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                key: const Key('simultaneous-default'),
                label: Text(
                  l10n?.memberSimultaneousLimitDefault ??
                      'Workspace default',
                ),
                selected: member.maxSimultaneousReservations == null,
                onSelected: (_) =>
                    Navigator.of(context).pop(defaultSentinel),
              ),
              for (final preset in presets)
                ChoiceChip(
                  key: Key('simultaneous-$preset'),
                  label: Text(preset.toString()),
                  selected: member.maxSimultaneousReservations == preset,
                  onSelected: (_) => Navigator.of(context).pop(preset),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
      ],
    ),
  );
  if (chosen == null || !context.mounted) return;
  final limit = chosen == defaultSentinel ? null : chosen;
  if (limit == member.maxSimultaneousReservations) return;

  if (!await runGuarded(
    context,
    domain: 'workspace',
    message: 'simultaneous limit update failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () => ref
        .read(workspaceRepositoryProvider)
        .setMemberSimultaneousLimit(member.id, limit),
  )) {
    return;
  }
  ref.invalidate(workspaceMembersProvider);
}

/// Flags [member] as a wall-mounted kiosk device — or reverts it
/// (0043, owner-only server-side). Kiosks lock to the plan view and act
/// only through member badges.
Future<void> toggleMemberKiosk(
  BuildContext context,
  WidgetRef ref,
  Member member,
) async {
  final l10n = AppLocalizations.of(context);
  if (!await runGuarded(
    context,
    domain: 'workspace',
    message: 'kiosk toggle failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () => ref
        .read(workspaceRepositoryProvider)
        .setMemberKiosk(member.id, isKiosk: !member.isKiosk),
  )) {
    return;
  }
  ref.invalidate(workspaceMembersProvider);
}

/// Whole-level grant (0050): flips can_reserve_level through the
/// admin/owner RPC (server refuses self-setting).
Future<void> toggleMemberLevelPermission(
  BuildContext context,
  WidgetRef ref,
  Member member,
) async {
  final l10n = AppLocalizations.of(context);
  if (!await runGuarded(
    context,
    domain: 'workspace',
    message: 'level permission toggle failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () => ref
        .read(workspaceRepositoryProvider)
        .setMemberLevelPermission(
          member.id,
          allowed: !member.canReserveLevel,
        ),
  )) {
    return;
  }
  ref.invalidate(workspaceMembersProvider);
}

/// New-member decision (0052): activates or exits a pending
/// membership through the admin/owner RPC.
Future<void> decideMemberJoin(
  BuildContext context,
  WidgetRef ref,
  Member member, {
  required bool approve,
}) async {
  final l10n = AppLocalizations.of(context);
  if (!await runGuarded(
    context,
    domain: 'workspace',
    message: 'member join decision failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () => ref
        .read(workspaceRepositoryProvider)
        .decideMemberJoin(member.id, approve: approve),
  )) {
    return;
  }
  ref.invalidate(workspaceMembersProvider);
}

/// Badge manager of one member (0043): the active/revoked badge list
/// with revoke buttons, and "New badge" which mints one and swaps the
/// dialog to the ONE-TIME QR of the raw token.
Future<void> showMemberBadgesDialog(
  BuildContext context,
  WidgetRef ref,
  Member member,
  String name,
) async {
  final l10n = AppLocalizations.of(context);
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null) return;
  await showDialog<void>(
    context: context,
    builder: (context) => BadgeManagerDialog(
      workspaceId: workspace.id,
      memberId: member.id,
      name: name,
      l10n: l10n,
      // Admin operations (0043/0046) — the member's Settings entry
      // injects the self-service RPCs instead (0053).
      issue: () => ref
          .read(workspaceRepositoryProvider)
          .issueMemberBadge(workspace.id, member.id),
      registerNfc: (uid) => ref
          .read(workspaceRepositoryProvider)
          .registerNfcBadge(workspace.id, member.id, uid: uid),
      revoke: (badgeId) => ref
          .read(workspaceRepositoryProvider)
          .revokeMemberBadge(badgeId),
      // Deletion is one shared RPC: the server allows the badge's own
      // member or an admin (0055).
      delete: (badgeId) => ref
          .read(workspaceRepositoryProvider)
          .deleteRevokedBadge(badgeId),
    ),
  );
}

/// Requests promoting/demotoggle the member's admin flag through the
/// validation quorum (0035): the change is pending until the
/// workspace's validators confirm it.
Future<void> requestMemberRoleChange(
  BuildContext context,
  WidgetRef ref,
  Member member,
) async {
  final l10n = AppLocalizations.of(context);
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null) return;
  final makeAdmin = !member.isAdmin;
  if (!await runGuarded(
    context,
    domain: 'workspace',
    message: 'role change request failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () async {
        await ref.read(workspaceRepositoryProvider).requestRoleChange(
              workspace.id,
              memberId: member.id,
              makeAdmin: makeAdmin,
            );
    },
  )) {
    return;
  }
  ref.invalidate(eventsProvider);
  if (!context.mounted) return;
  AppSnack.success(
    context,
    l10n?.memberRoleChangeRequested ?? 'Role change sent for validation.',
  );
}

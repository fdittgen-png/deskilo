// SPDX-License-Identifier: 0BSD
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../money/presentation/widgets/consumption_sheet.dart';
import '../../../money/providers/money_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../domain/member.dart';
import '../../domain/overage_policy.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/badge_manager_dialog.dart';
import '../../../events/providers/event_providers.dart';

/// Owner-only member management: role overview, subscription percentage
/// assignment (#128, ADR 0008), pause/reactivate (spec §7.2).
class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  Future<void> _pickSubscription(
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
  Future<void> _pickOveragePolicy(
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
        title: Text(l10n?.memberOveragePolicyLabel ?? 'When days run out'),
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

  /// The one management surface of a member (UX pass): every action as a
  /// labeled tile, gated by the same rules the old icon buttons carried —
  /// owner-only knobs, no self reservation-limit, no billing for kiosks.
  Future<void> _memberSheet(
    BuildContext context,
    WidgetRef ref,
    Member member,
    String name, {
    required bool isOwner,
    required bool isSelf,
    required bool servicesOn,
    required bool levelBookingOn,
  }) async {
    final l10n = AppLocalizations.of(context);
    final active = member.status == MemberStatus.active;
    final pending = member.status == MemberStatus.pending;
    final actions = <Widget>[
      // New-member validation (0052): a pending membership offers the
      // decision first — approve activates, reject exits. The quorum
      // path on the events feed stays available in parallel.
      if (pending && !isSelf)
        _sheetAction(
          context,
          icon: Icons.how_to_reg_outlined,
          label: l10n?.memberApprove ?? 'Approve membership',
          onTap: () => _decideJoin(context, ref, member, approve: true),
        ),
      if (pending && !isSelf)
        _sheetAction(
          context,
          icon: Icons.person_off_outlined,
          label: l10n?.memberRejectJoin ?? 'Reject membership',
          onTap: () => _decideJoin(context, ref, member, approve: false),
        ),
      if (servicesOn && !member.isKiosk && active)
        _sheetAction(
          context,
          icon: Icons.room_service_outlined,
          label: l10n?.consumptionAddForMember(name) ?? 'Add service for $name',
          onTap: () => showConsumptionSheet(
            context,
            ref,
            subjectMemberId: member.id,
            subjectName: name,
          ),
        ),
      if (isOwner && !member.isKiosk)
        _sheetAction(
          context,
          icon: Icons.percent,
          label: l10n?.memberSubscriptionLabel ?? 'Subscription',
          onTap: () => _pickSubscription(context, ref, member),
        ),
      if (isOwner && !member.isKiosk && active)
        _sheetAction(
          context,
          icon: member.overagePolicy == OveragePolicy.blocked
              ? Icons.speed_outlined
              : Icons.speed,
          label: l10n?.memberOveragePolicyLabel ?? 'When days run out',
          onTap: () => _pickOveragePolicy(context, ref, member),
        ),
      if (!isSelf && !member.isKiosk && active)
        _sheetAction(
          context,
          icon: Icons.stacked_bar_chart_outlined,
          label: l10n?.memberReservationLimitLabel ?? 'Reservation limit',
          onTap: () => _pickReservationLimit(context, ref, member),
        ),
      // Whole-level reservations (0050): grant/revoke — owner or admin,
      // never self (the reservation-limit rule), feature-gated.
      if (levelBookingOn && !isSelf && !member.isKiosk && active)
        _sheetAction(
          context,
          icon: member.canReserveLevel
              ? Icons.layers
              : Icons.layers_outlined,
          label: member.canReserveLevel
              ? (l10n?.levelPermissionAllowed ??
                  'May reserve a whole level')
              : (l10n?.levelPermissionDenied ??
                  'May not reserve a whole level'),
          onTap: () => _toggleLevelPermission(context, ref, member),
        ),
      if (!member.isKiosk && !member.isOwner && active)
        _sheetAction(
          context,
          icon: Icons.qr_code_2_outlined,
          label: l10n?.memberBadgesTooltip ?? 'Badges',
          onTap: () => _badgesDialog(context, ref, member, name),
        ),
      if (isOwner && !member.isOwner && !member.isKiosk && active)
        _sheetAction(
          context,
          icon: member.isAdmin
              ? Icons.remove_moderator_outlined
              : Icons.add_moderator_outlined,
          label: member.isAdmin
              ? (l10n?.memberMakeMember ?? 'Make regular member')
              : (l10n?.memberMakeAdmin ?? 'Make admin'),
          onTap: () => _changeRole(context, ref, member),
        ),
      if (isOwner && !member.isOwner && active)
        _sheetAction(
          context,
          icon: member.isKiosk
              ? Icons.tablet_mac
              : Icons.tablet_mac_outlined,
          label: member.isKiosk
              ? (l10n?.memberUnmakeKiosk ?? 'Revert kiosk to member')
              : (l10n?.memberMakeKiosk ?? 'Make kiosk device'),
          onTap: () => _toggleKiosk(context, ref, member),
        ),
      // Pause/reactivate was a hidden long-press before — now a visible,
      // named action.
      if (isOwner && member.status != MemberStatus.exited)
        _sheetAction(
          context,
          icon: member.status == MemberStatus.paused
              ? Icons.play_circle_outline
              : Icons.pause_circle_outline,
          label: member.status == MemberStatus.paused
              ? (l10n?.memberReactivate ?? 'Reactivate membership')
              : (l10n?.memberPause ?? 'Pause membership'),
          onTap: () => _togglePaused(context, ref, member),
        ),
    ];
    if (actions.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: SheetShell(title: name, children: actions),
        ),
      ),
    );
  }

  /// One labeled sheet action: closes the sheet, then runs [onTap] with
  /// the SCREEN's context (the sheet's dies with the pop).
  Widget _sheetAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    // Builder: the tile's own context lives under the sheet route, so the
    // pop closes the SHEET — the action then runs on the screen's context.
    return Builder(
      builder: (tileContext) => ListTile(
        leading: Icon(icon),
        title: Text(label),
        onTap: () {
          Navigator.of(tileContext).pop();
          onTap();
        },
      ),
    );
  }

  Future<void> _togglePaused(
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
  Future<void> _pickReservationLimit(
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

  /// Flags [member] as a wall-mounted kiosk device — or reverts it
  /// (0043, owner-only server-side). Kiosks lock to the plan view and act
  /// only through member badges.
  Future<void> _toggleKiosk(
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
  Future<void> _toggleLevelPermission(
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
  Future<void> _decideJoin(
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
  Future<void> _badgesDialog(
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
      ),
    );
  }

  /// Requests promoting/demotoggle the member's admin flag through the
  /// validation quorum (0035): the change is pending until the
  /// workspace's validators confirm it.
  Future<void> _changeRole(
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final membersAsync = ref.watch(workspaceMembersProvider);
    final names = ref.watch(memberNamesProvider).value ?? const {};
    // Admins reach this screen too (0044); owner-only controls gate on
    // [isOwner], and the self row never offers the reservation limit.
    final me = ref.watch(myMemberProvider).value;
    final isOwner = me?.isOwner ?? false;
    // Consumption entry points follow the services feature (#146).
    final features = ref.watch(enabledFeaturesSyncProvider);
    final servicesOn = features.contains(WorkspaceFeature.services);
    final levelBookingOn =
        features.contains(WorkspaceFeature.levelBooking);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.membersTitle ?? 'Members & plans'),
        actions: [
          // Invite entry point (#195): the members list is where owners
          // notice someone is missing. Links to the owner-only workspace
          // ID & QR and billing surfaces — hidden from plain admins.
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              tooltip: l10n?.membersInvite ?? 'Invite a member',
              onPressed: () => context.push('/workspace-code'),
            ),
          if (isOwner)
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: l10n?.billingTitle ?? 'Billing',
            onPressed: () => context.push('/billing'),
          ),
        ],
      ),
      body: switch (membersAsync) {
        AsyncData(value: final members) => ListView(
            children: [
              for (final member in members)
                ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      (names[member.id] ?? '?').isEmpty
                          ? '?'
                          : (names[member.id] ?? '?')
                              .substring(0, 1)
                              .toUpperCase(),
                    ),
                  ),
                  title: Text(names[member.id] ?? ''),
                  subtitle: Wrap(
                    spacing: 6,
                    children: [
                      // A kiosk is a device, not a paying member — no
                      // subscription line.
                      if (!member.isKiosk)
                        Text(
                          l10n?.percentValue(member.subscriptionPct) ??
                              '${member.subscriptionPct}%',
                        ),
                      if (member.isKiosk)
                        Text(l10n?.memberKioskLabel ?? 'Kiosk'),
                      if (member.maxActiveReservations != null)
                        Text(
                          l10n?.memberReservationLimitChip(
                                member.maxActiveReservations!,
                              ) ??
                              'max ${member.maxActiveReservations}',
                        ),
                      if (member.isOwner)
                        Text(l10n?.memberRoleOwner ?? 'Owner'),
                      if (member.isAdmin && !member.isOwner)
                        Text(l10n?.memberRoleAdmin ?? 'Admin'),
                      if (member.status == MemberStatus.pending)
                        Text(
                          l10n?.memberStatusPending ?? 'Pending',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (member.status == MemberStatus.paused)
                        Text(l10n?.memberStatusPaused ?? 'Paused'),
                      if (member.status == MemberStatus.exited)
                        Text(l10n?.memberStatusExited ?? 'Exited'),
                    ],
                  ),
                  // One labeled management surface per member (UX pass):
                  // the row opens a sheet of named actions instead of a
                  // pile of cryptic icon buttons (which overflowed on
                  // phones) and a hidden long-press.
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _memberSheet(
                    context,
                    ref,
                    member,
                    names[member.id] ?? '',
                    isOwner: isOwner,
                    isSelf: member.id == me?.id,
                    servicesOn: servicesOn,
                    levelBookingOn: levelBookingOn,
                  ),
                ),
            ],
          ),
        AsyncError() => Center(
            child: Text(
              l10n?.workspaceGenericError ??
                  'Something went wrong. Please try again.',
            ),
          ),
        _ => const LoadingView(),
      },
    );
  }
}

/// Stateful badge manager (0043): shows the member's badges with revoke
/// actions; issuing swaps the body to the raw token's QR — the only time
/// it ever exists client-side.

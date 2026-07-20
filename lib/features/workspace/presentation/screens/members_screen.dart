// SPDX-License-Identifier: MIT
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../money/presentation/widgets/consumption_sheet.dart';
import '../../../money/providers/money_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../domain/member.dart';
import '../../domain/member_badge.dart';
import '../../domain/overage_policy.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';
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
      builder: (context) => _BadgesDialog(
        workspaceId: workspace.id,
        member: member,
        name: name,
        l10n: l10n,
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
    final servicesOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.services);

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
                      if (member.status == MemberStatus.paused)
                        Text(l10n?.memberStatusPaused ?? 'Paused'),
                      if (member.status == MemberStatus.exited)
                        Text(l10n?.memberStatusExited ?? 'Exited'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Consumed services land on the member's bill only
                      // after the member confirms (#129).
                      if (servicesOn &&
                          !member.isKiosk &&
                          member.status == MemberStatus.active)
                        IconButton(
                          icon: const Icon(Icons.room_service_outlined),
                          tooltip: l10n?.consumptionAddForMember(
                                names[member.id] ?? '',
                              ) ??
                              'Add service for ${names[member.id] ?? ''}',
                          onPressed: () => showConsumptionSheet(
                            context,
                            ref,
                            subjectMemberId: member.id,
                            subjectName: names[member.id] ?? '',
                          ),
                        ),
                      // Promote/demote through the validation quorum (0035):
                      // owners are excluded (they keep admin), exited
                      // members can't be re-roled.
                      if (isOwner &&
                          !member.isOwner &&
                          !member.isKiosk &&
                          member.status == MemberStatus.active)
                        IconButton(
                          icon: Icon(
                            member.isAdmin
                                ? Icons.remove_moderator_outlined
                                : Icons.add_moderator_outlined,
                          ),
                          tooltip: member.isAdmin
                              ? (l10n?.memberMakeMember ??
                                  'Make regular member')
                              : (l10n?.memberMakeAdmin ?? 'Make admin'),
                          onPressed: () => _changeRole(context, ref, member),
                        ),
                      if (isOwner && !member.isKiosk)
                        IconButton(
                          icon: const Icon(Icons.percent),
                          tooltip:
                              l10n?.memberSubscriptionLabel ?? 'Subscription',
                          onPressed: () =>
                              _pickSubscription(context, ref, member),
                        ),
                      // Over-consumption policy (0041): block past the plan,
                      // or bill overage pay-as-you-go.
                      if (isOwner &&
                          !member.isKiosk &&
                          member.status == MemberStatus.active)
                        IconButton(
                          icon: Icon(
                            member.overagePolicy == OveragePolicy.blocked
                                ? Icons.speed_outlined
                                : Icons.speed,
                          ),
                          tooltip: l10n?.memberOveragePolicyTooltip ??
                              'Over-consumption',
                          onPressed: () =>
                              _pickOveragePolicy(context, ref, member),
                        ),
                      // Kiosk badges (0043): mint/revoke the QR badges the
                      // member presents at a wall tablet.
                      if (!member.isKiosk &&
                          !member.isOwner &&
                          member.status == MemberStatus.active)
                        IconButton(
                          icon: const Icon(Icons.qr_code_2_outlined),
                          tooltip: l10n?.memberBadgesTooltip ?? 'Badges',
                          onPressed: () => _badgesDialog(
                            context,
                            ref,
                            member,
                            names[member.id] ?? '',
                          ),
                        ),
                      // Cap on simultaneous open reservations (0044):
                      // admins and owners set it for OTHERS — the server
                      // refuses self-setting, so the self row hides it.
                      if (member.id != me?.id &&
                          !member.isKiosk &&
                          member.status == MemberStatus.active)
                        IconButton(
                          icon: Icon(
                            member.maxActiveReservations == null
                                ? Icons.stacked_bar_chart_outlined
                                : Icons.stacked_bar_chart,
                          ),
                          tooltip: l10n?.memberReservationLimitTooltip ??
                              'Reservation limit',
                          onPressed: () =>
                              _pickReservationLimit(context, ref, member),
                        ),
                      // Kiosk device flag (0043, owner-only server-side).
                      if (isOwner &&
                          !member.isOwner &&
                          member.status == MemberStatus.active)
                        IconButton(
                          icon: Icon(
                            member.isKiosk
                                ? Icons.tablet_mac
                                : Icons.tablet_mac_outlined,
                          ),
                          tooltip: member.isKiosk
                              ? (l10n?.memberUnmakeKiosk ??
                                  'Revert kiosk to member')
                              : (l10n?.memberMakeKiosk ??
                                  'Make kiosk device'),
                          onPressed: () =>
                              _toggleKiosk(context, ref, member),
                        ),
                    ],
                  ),
                  onLongPress: !isOwner ||
                          member.status == MemberStatus.exited
                      ? null
                      : () async {
                          final paused =
                              member.status == MemberStatus.paused;
                          await ref
                              .read(workspaceRepositoryProvider)
                              .updateMemberStatus(
                                member.id,
                                paused
                                    ? MemberStatus.active
                                    : MemberStatus.paused,
                              );
                          ref.invalidate(workspaceMembersProvider);
                        },
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
class _BadgesDialog extends ConsumerStatefulWidget {
  const _BadgesDialog({
    required this.workspaceId,
    required this.member,
    required this.name,
    required this.l10n,
  });

  final String workspaceId;
  final Member member;
  final String name;
  final AppLocalizations? l10n;

  @override
  ConsumerState<_BadgesDialog> createState() => _BadgesDialogState();
}

class _BadgesDialogState extends ConsumerState<_BadgesDialog> {
  List<MemberBadge>? _badges;

  /// Set right after issuing: the one-time raw token to render as a QR.
  IssuedBadge? _issued;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l10n = widget.l10n;
    List<MemberBadge> all = const [];
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'badge list failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        all = await ref
            .read(workspaceRepositoryProvider)
            .fetchMemberBadges(widget.workspaceId);
      },
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _badges =
        [for (final b in all) if (b.memberId == widget.member.id) b]);
  }

  Future<void> _issue() async {
    final l10n = widget.l10n;
    IssuedBadge? issued;
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'badge issue failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        issued = await ref
            .read(workspaceRepositoryProvider)
            .issueMemberBadge(widget.workspaceId, widget.member.id);
      },
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _issued = issued);
    unawaited(_load());
  }

  Future<void> _revoke(MemberBadge badge) async {
    final l10n = widget.l10n;
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'badge revoke failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () =>
          ref.read(workspaceRepositoryProvider).revokeMemberBadge(badge.id),
    )) {
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final issued = _issued;
    final badges = _badges;
    final badgeCountOf = badges?.length ?? 0;
    return AlertDialog(
      title: Text(
        l10n?.memberBadgesTitle(widget.name) ?? 'Badges — ${widget.name}',
      ),
      content: SizedBox(
        width: 320,
        child: issued != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The raw token, once: print it or let the member scan
                  // it into their badge wallet.
                  Center(
                    child: QrImageView(
                      key: const ValueKey('badge-qr'),
                      data: issued.token,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n?.badgeTokenOnce ??
                        'Save this QR now — it is shown only once.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : badges == null
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (badgeCountOf == 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            l10n?.badgeNone ?? 'No badges yet.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      for (final badge in badges)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            badge.isActive
                                ? Icons.badge_outlined
                                : Icons.block_outlined,
                          ),
                          title: Text(
                            badge.label.isEmpty
                                ? (l10n?.badgeDefaultLabel ?? 'Badge')
                                : badge.label,
                          ),
                          subtitle: badge.isActive
                              ? null
                              : Text(l10n?.badgeRevoked ?? 'Revoked'),
                          trailing: badge.isActive
                              ? TextButton(
                                  onPressed: () => _revoke(badge),
                                  child: Text(
                                    l10n?.badgeRevoke ?? 'Revoke',
                                  ),
                                )
                              : null,
                        ),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonClose ?? 'Close'),
        ),
        if (issued == null)
          FilledButton.icon(
            key: const ValueKey('badge-issue-button'),
            onPressed: _issue,
            icon: const Icon(Icons.qr_code_2_outlined),
            label: Text(l10n?.badgeIssue ?? 'New badge'),
          ),
      ],
    );
  }
}

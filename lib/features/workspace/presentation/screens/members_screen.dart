// SPDX-License-Identifier: 0BSD
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../money/presentation/widgets/consumption_sheet.dart';
import '../../../money/providers/money_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../domain/member.dart';
import '../../../../core/files/file_saver.dart';
import '../../../../core/nfc/nfc_uid_reader.dart';
import '../../domain/badge_pdf.dart';
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

  /// Whether this device can read an RFID/NFC tap (Android + NFC on).
  bool _nfcAvailable = false;

  @override
  void initState() {
    super.initState();
    _load();
    _checkNfc();
  }

  Future<void> _checkNfc() async {
    // Both the workspace toggle AND this device's hardware must allow it.
    final enabled = ref
        .read(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.nfcBadges);
    final available =
        enabled && await ref.read(nfcUidReaderProvider).isAvailable();
    if (mounted) setState(() => _nfcAvailable = available);
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

  /// Downloads the freshly issued badge as a printable PDF card (the QR
  /// exists only in this dialog — this is the moment to keep it).
  Future<void> _savePdf(IssuedBadge issued) async {
    final l10n = widget.l10n;
    final workspaceName =
        ref.read(currentWorkspaceProvider).value?.name ?? '';
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'badge PDF export failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        // Embedded Roboto like the bill PDF: accented names must encode.
        final regular =
            await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
        final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
        final bytes = await buildBadgePdf(
          workspaceName: workspaceName,
          memberName: widget.name,
          token: issued.token,
          hint: l10n?.kioskPresentBadge ?? 'Present your badge',
          baseFont: pw.Font.ttf(regular),
          boldFont: pw.Font.ttf(bold),
        );
        final safeName = widget.name
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
        final path = await ref.read(fileSaverProvider)(
          bytes: bytes,
          fileName: 'deskilo-badge-$safeName.pdf',
        );
        if (!mounted) return;
        if (path == null) {
          AppSnack.error(
            context,
            l10n?.commonSaveFailed ?? 'Could not save.',
          );
        } else {
          AppSnack.success(
            context,
            l10n?.commonSavedTo(path) ?? 'Saved to $path',
          );
        }
      },
    )) {
      return;
    }
  }

  /// Registers a physical RFID/NFC card as this member's badge (0046):
  /// prompt "tap the card", read its UID, hand it to the server. The
  /// reader session is always stopped, and a re-registered tag maps to
  /// its own message.
  Future<void> _registerNfc() async {
    final l10n = widget.l10n;
    final reader = ref.read(nfcUidReaderProvider);
    final uid = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _NfcTapDialog(reader: reader, l10n: l10n),
    );
    if (uid == null || uid.isEmpty || !mounted) return;

    var duplicate = false;
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'nfc badge registration failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        try {
          await ref.read(workspaceRepositoryProvider).registerNfcBadge(
                widget.workspaceId,
                widget.member.id,
                uid: uid,
              );
        } on PostgrestException catch (e, st) {
          if (e.message.contains('tag already registered')) {
            duplicate = true;
            return; // handled below, not a generic failure
          }
          // trace-exempt: rethrown to runGuarded, which logs it.
          Error.throwWithStackTrace(e, st);
        }
      },
    )) {
      return;
    }
    if (!mounted) return;
    if (duplicate) {
      AppSnack.error(
        context,
        l10n?.badgeCardAlreadyRegistered ??
            'That card is already registered.',
      );
      return;
    }
    AppSnack.success(
      context,
      l10n?.badgeCardRegistered ?? 'Card registered.',
    );
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
                            !badge.isActive
                                ? Icons.block_outlined
                                : badge.kind == BadgeKind.nfc
                                    ? Icons.contactless_outlined
                                    : Icons.qr_code_2_outlined,
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
        // Download & print the one-time QR as a badge card (UX pass).
        if (issued != null)
          FilledButton.icon(
            key: const ValueKey('badge-save-pdf'),
            onPressed: () => _savePdf(issued),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(l10n?.badgeSavePdf ?? 'Save as PDF'),
          ),
        if (issued == null && _nfcAvailable)
          OutlinedButton.icon(
            key: const ValueKey('badge-register-nfc-button'),
            onPressed: _registerNfc,
            icon: const Icon(Icons.contactless_outlined),
            label: Text(l10n?.badgeRegisterCard ?? 'Register card'),
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

/// "Tap the card" prompt (0046): starts an NFC read session and pops with
/// the first tag's normalized UID. Owns the session lifecycle so it is
/// always stopped, whether the user taps a card or cancels.
class _NfcTapDialog extends StatefulWidget {
  const _NfcTapDialog({required this.reader, required this.l10n});

  final NfcUidReader reader;
  final AppLocalizations? l10n;

  @override
  State<_NfcTapDialog> createState() => _NfcTapDialogState();
}

class _NfcTapDialogState extends State<_NfcTapDialog> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      widget.reader.startRead(
        onUid: (uid) {
          if (_done || !mounted) return;
          _done = true;
          Navigator.of(context).pop(uid);
        },
      ),
    );
  }

  @override
  void dispose() {
    unawaited(widget.reader.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n?.badgeTapCardTitle ?? 'Register a card'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Icon(Icons.contactless_outlined, size: 56),
          ),
          Text(
            l10n?.badgeTapCardHint ??
                'Hold the RFID/NFC card to the back of the device.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('nfc-tap-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
      ],
    );
  }
}

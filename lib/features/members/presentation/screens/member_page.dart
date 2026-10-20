// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/links/link_launcher.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/settings/directory_windows.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/vat/vat_treatment.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../money/presentation/widgets/consumption_sheet.dart';
import '../../../money/presentation/widgets/member_billing_tiles.dart';
import '../../../money/presentation/widgets/negotiation_card.dart';
import '../../../money/presentation/widgets/payment_terms_card.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../profile/domain/personal_info.dart';
import '../../../profile/presentation/courtesy_words.dart';
import '../../../profile/presentation/widgets/member_avatar.dart';
import '../../../reservations/domain/reservation.dart';
import '../../../reservations/presentation/widgets/reservation_detail_sheet.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/booking_policies.dart';
import '../../../workspace/domain/invite_uri.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/domain/overage_policy.dart';
import '../../../workspace/domain/site.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../../workspace/presentation/member_admin_actions.dart';
import '../../../workspace/presentation/member_customer_capacity.dart';
import '../../../workspace/presentation/member_einvoice_address_tile.dart';
import '../../../workspace/presentation/member_labels.dart';
import '../../../workspace/presentation/member_vat_treatment.dart';
import '../../../workspace/presentation/widgets/invite_sheet.dart';
import '../../../workspace/presentation/widgets/member_roles_card.dart';
import '../../../workspace/presentation/widgets/open_conversation.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/directory_status.dart';
import '../../providers/directory_providers.dart';
import '../widgets/member_contact_card.dart';
import '../widgets/member_money_card.dart';

part '../widgets/member_page_cards.dart';

/// #825 — ONE page per person (`/member/:id`): who they are and whether
/// they are here, what they have booked, how to reach them, their money
/// position where the viewer may see it — and, for admins, everything
/// that can be changed about them, grouped by topic with the CURRENT
/// value on every row. It replaces two surfaces that never met: the
/// read-only profile sheet of the directory and the flat seventeen-row
/// action sheet of Members & plans.
class MemberPage extends ConsumerWidget {
  const MemberPage({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final membersAsync = ref.watch(workspaceMembersProvider);
    final member = membersAsync.value?.where((m) => m.id == memberId).firstOrNull;
    if (member == null) {
      return Scaffold(
        appBar: AppBar(),
        body: membersAsync.isLoading
            ? const LoadingView()
            : EmptyState(
                icon: Icons.person_off_outlined,
                title: l10n.workspaceGenericError,
              ),
      );
    }
    final name = ref.watch(memberNamesProvider).value?[memberId] ?? '';
    return _MemberPageBody(member: member, name: name);
  }
}

class _MemberPageBody extends ConsumerWidget {
  const _MemberPageBody({required this.member, required this.name});

  final Member member;
  final String name;

  /// "Wed 2 · 08:00 · A1" — the directory's house style for a booking.
  static String bookingLabel(AppFormat format, Reservation reservation, String seatName) {
    final local = reservation.startsAt.toLocal();
    final day =
        '${DateFormat.E().format(local)} ${DateFormat.d().format(local)}';
    final when = '$day · ${format.time(reservation.startsAt)}';
    return seatName.isEmpty ? when : '$when · $seatName';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider).now();
    final me = ref.watch(myMemberProvider).value;
    final isSelf = me?.id == member.id;
    final features = ref.watch(enabledFeaturesSyncProvider);
    final perms = ref.watch(myPermissionsProvider);
    final profile = ref.watch(memberProfilesProvider).value?[member.userId];
    final email = ref.watch(memberEmailsProvider).value?[member.id] ?? '';
    final reservations =
        ref.watch(directoryReservationsProvider).value ?? const <Reservation>[];
    final targets = ref.watch(targetNamesProvider).value ?? const {};
    final policies =
        ref.watch(bookingPoliciesProvider).value ?? const BookingPolicies();
    final windows = ref.watch(directoryWindowsProvider);
    final presence = resolveDirectoryPresence(lastSeenAt: profile?.lastSeenAt, now: now, isSelf: isSelf, onlineWindow: windows.onlineWindow);
    final info = resolveReservationInfo(memberId: member.id, reservations: reservations, now: now, upcomingWindow: windows.upcomingWindow);
    final upcoming = [
      for (final r in reservations)
        if (r.memberId == member.id && r.endsAt.isAfter(now)) r,
    ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    final active = member.status == MemberStatus.active;
    final pending = member.status == MemberStatus.pending;
    final canAdmin = me?.canAdminister ?? false;
    final isOwner = me?.actsAsOwner ?? false;
    final whatsappOn = features.contains(WorkspaceFeature.whatsappIntegration);
    final whatsappUri = whatsappOn ? profile?.whatsappUri : null;
    final notesOn = features.contains(WorkspaceFeature.memberNotifications);
    // #887 — nobody reads a message sent to a managed member.
    final canMessage =
        notesOn && !isSelf && !member.isKiosk && !member.isManaged && active;
    final servicesOn = features.contains(WorkspaceFeature.services);
    final reportsOn = features.contains(WorkspaceFeature.memberReports);
    final kioskOn = features.contains(WorkspaceFeature.kioskMode);
    final coOwnerOn = features.contains(WorkspaceFeature.coOwner);
    final levelOn = features.contains(WorkspaceFeature.levelBooking);
    final rolesOn = features.contains(WorkspaceFeature.roleAssignment);
    final negotiationVisible = !isSelf &&
        me != null &&
        features.contains(WorkspaceFeature.priceNegotiations) &&
        (isOwner ||
            perms.contains(WorkspacePermission.manageNegotiations) ||
            perms.contains(WorkspacePermission.viewNegotiations));

    final c = _PageCtx(
      context: context,
      ref: ref,
      member: member,
      name: name,
      l10n: l10n,
      me: me,
      features: features,
      perms: perms,
      email: email,
      policies: policies,
      isSelf: isSelf,
      active: active,
      pending: pending,
      canAdmin: canAdmin,
      isOwner: isOwner,
      whatsappUri: whatsappUri,
      canMessage: canMessage,
      servicesOn: servicesOn,
      reportsOn: reportsOn,
      kioskOn: kioskOn,
      coOwnerOn: coOwnerOn,
      levelOn: levelOn,
      rolesOn: rolesOn,
      negotiationVisible: negotiationVisible,
    );
    final quickActions = _quickActions(c);

    // ---- the admin groups: every row carries its CURRENT value.
    final membership = _membershipTiles(c);
    final booking = _bookingTiles(c);
    final billing = _billingTiles(c);
    final access = _accessTiles(c);
    final groups = <(String, List<Widget>)>[
      (l10n.memberPageGroupMembership, membership),
      (l10n.memberPageGroupBooking, booking),
      (l10n.memberPageGroupBilling, billing),
      (l10n.memberPageGroupAccess, access),
    ].where((g) => g.$2.isNotEmpty).toList();

    return Scaffold(
      key: const ValueKey('member-page'),
      appBar: AppBar(
        title: Text(name, overflow: TextOverflow.ellipsis),
        actions: [
          if (canMessage)
            IconButton(
              key: const ValueKey('member-page-message'),
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: l10n.memberMessagesAction,
              onPressed: () =>
                  openDirectConversation(context, ref, memberId: member.id),
            ),
        ],
      ),
      body: _MemberSections(
        sections: [
          _MemberSection(
            'profile',
            l10n.uxProfileSection,
            [
              _HeaderCard(
                member: member,
                name: name,
                isSelf: isSelf,
                hasAvatar: profile?.hasAvatar ?? false,
                statusText: profile?.statusText ?? '',
                presence: presence,
                now: now,
              ),
              const SizedBox(height: AppSpacing.md),
              _NowCard(
                info: info,
                upcoming: upcoming,
                targets: targets,
                onOpen: (r) => showReservationDetail(context, ref, r),
              ),
              if (quickActions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                // #1187 — the actions were a Wrap of buttons each sized to
                // its own label: three rows, three widths, ragged right. Two
                // equal columns instead, and a lone last button spans them,
                // so the group reads as a group.
                LayoutBuilder(
                  key: const ValueKey('member-page-actions'),
                  builder: (context, constraints) {
                    const gap = AppSpacing.sm;
                    final cell = (constraints.maxWidth - gap) / 2;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final (i, action) in quickActions.indexed)
                          SizedBox(
                            key: ValueKey('member-page-cell-$i'),
                            // A lone last button spans both columns rather
                            // than sitting half-width beside nothing.
                            width: i == quickActions.length - 1 && i.isEven
                                ? constraints.maxWidth
                                : cell,
                            child: action,
                          ),
                      ],
                    );
                  },
                ),
              ],
              // Role-gated INSIDE each card, as on the old sheet.
              MemberContactCard(member: member, isSelf: isSelf),
              MemberMoneyCard(memberId: member.id, isSelf: isSelf),
            ],
          ),
          // #2085 — the one place a member is given a role.
          if (rolesOn &&
              !member.isKiosk &&
              (isSelf ||
                  canAdmin ||
                  perms.contains(WorkspacePermission.manageRoles)))
            _MemberSection('roles', l10n.memberRolesTitle, [
              MemberRolesCard(member: member, name: name),
            ], showHeading: false),
          if (groups.isNotEmpty)
            _MemberSection(
              'manage',
              l10n.memberPageManageHeading,
              [
                for (final (title, tiles) in groups)
                  Card(
                    margin: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.md,
                            AppSpacing.lg,
                            0,
                          ),
                          child: Text(
                            title,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        ...tiles,
                      ],
                    ),
                  ),
              ],
            ),
          if (features.contains(WorkspaceFeature.memberPaymentTerms) &&
              (isSelf || canAdmin))
            _MemberSection(
              'payment-terms',
              l10n.paymentTermsTitle,
              [PaymentTermsCard(member: member, isSelf: isSelf)],
              showHeading: false,
            ),
        ],
      ),
    );
  }

}

class _MemberSection {
  const _MemberSection(this.id, this.title, this.children, {this.showHeading = true});

  final String id;
  final String title;
  final List<Widget> children;
  final bool showHeading;
}

/// The same section shortcuts and reading width as Profile and account.
/// All sections stay mounted so keyboard focus and guide highlights can reach
/// a control below the fold without switching away from the member's form.
class _MemberSections extends StatefulWidget {
  const _MemberSections({required this.sections});

  final List<_MemberSection> sections;

  @override
  State<_MemberSections> createState() => _MemberSectionsState();
}

class _MemberSectionsState extends State<_MemberSections> {
  final _anchors = <String, GlobalKey>{};
  final _focus = <String, FocusNode>{};

  @override
  void dispose() {
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _jump(String id) {
    final target = _anchors[id]?.currentContext;
    if (target == null) return;
    _focus[id]?.requestFocus();
    Scrollable.ensureVisible(
      target,
      duration: motionDuration(context, MotionTokens.standard),
    );
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        children: [
          Padding(
            padding: AppSpacing.smAll,
            child: Wrap(
              key: const ValueKey('member-section-navigation'),
              spacing: AppSpacing.xs,
              children: [
                for (final section in widget.sections)
                  TextButton(
                    key: ValueKey('member-section-${section.id}'),
                    onPressed: () => _jump(section.id),
                    child: Text(section.title),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey('member-page-sections'),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                for (final section in widget.sections)
                    Focus(
                      key: _anchors.putIfAbsent(section.id, GlobalKey.new),
                      focusNode: _focus.putIfAbsent(
                        section.id,
                        () => FocusNode(skipTraversal: true),
                      ),
                    child: section.showHeading
                        ? FormSection(
                            key: ValueKey('member-page-${section.id}'),
                            title: section.title,
                            children: section.children,
                          )
                        : Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: section.children,
                            ),
                          ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// "Seen 20 h ago" — the directory's relative last-seen label, shared
/// with the row chip (#825: it now says what the number means).
String relativeLastSeen(
  AppLocalizations l10n,
  DateTime now,
  DateTime lastSeenAt,
) {
  final diff = now.difference(lastSeenAt);
  if (diff.inMinutes < 60) {
    final minutes = diff.inMinutes < 1 ? 1 : diff.inMinutes;
    return l10n.directoryLastSeenMinutes(minutes);
  }
  if (diff.inHours < 24) {
    final hours = diff.inHours;
    return l10n.directoryLastSeenHours(hours);
  }
  final days = diff.inDays;
  return l10n.directoryLastSeenDays(days);
}

/// #887 — takes an unredeemed handover back; the member stays managed.

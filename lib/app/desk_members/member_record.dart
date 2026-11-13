// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3618 — a member at their address `/members/<id>`: beside the members'
// table on a large window, a page otherwise, with tabs: profile (the member
// page's own sections), plan, bookings, invoices and notes. A tab the
// person may not see is not there: invoices for the finance readers and the
// member themself, notes where a note can be sent.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_format.dart';
import '../../core/i18n/format_controller.dart';
import '../../core/l10n/context_l10n.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/time/clock.dart';
import '../../features/members/presentation/screens/member_page.dart';
import '../../features/members/presentation/widgets/member_money_card.dart';
import '../../features/plan/providers/floor_plan_providers.dart';
import '../../features/reservations/domain/reservation.dart';
import '../../features/reservations/presentation/widgets/reservation_detail_sheet.dart';
import '../../features/workspace/domain/member.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/presentation/widgets/member_note_dialog.dart';
import '../../features/workspace/presentation/widgets/open_conversation.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import 'member_desk_providers.dart';
import 'member_plan_tab.dart';
import 'members_desk.dart';

/// The member [memberId], with their tabs.
class MemberRecord extends ConsumerWidget {
  const MemberRecord({super.key, required this.memberId, this.onClose});

  final String memberId;

  /// Set when the member stands beside the table: its close button.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final members = ref.watch(workspaceMembersProvider).value;
    final member = members?.where((m) => m.id == memberId).firstOrNull;
    final me = ref.watch(myMemberProvider).value;
    final rights = membersDeskRights(me, ref.watch(myPermissionsProvider));
    final isSelf = me?.id == memberId;
    final features = ref.watch(enabledFeaturesSyncProvider);
    final name = ref.watch(memberNamesProvider).value?[memberId] ?? '';
    final notes =
        member != null &&
        !isSelf &&
        features.contains(WorkspaceFeature.memberNotifications) &&
        member.status == MemberStatus.active &&
        !member.isKiosk &&
        !member.isManaged;
    final tabs = <(String, String, Widget)>[
      (
        'profile',
        l.membersTabProfile,
        MemberPage(memberId: memberId, framed: false),
      ),
      if (member != null) ...[
        (
          'plan',
          l.membersTabPlan,
          MemberPlanTab(member: member, rights: rights),
        ),
        ('bookings', l.membersTabBookings, _Bookings(memberId: memberId)),
        if (rights.seesOpen || isSelf)
          (
            'invoices',
            l.customerPageInvoices,
            SingleChildScrollView(
              padding: AppSpacing.lgAll,
              child: MemberMoneyCard(memberId: memberId, isSelf: isSelf),
            ),
          ),
        if (notes)
          ('notes', l.membersTabNotes, _Notes(member: member, name: name)),
      ],
    ];
    final bar = AppBar(
      title: Text(name, overflow: TextOverflow.ellipsis),
      automaticallyImplyLeading: onClose == null,
      actions: [
        if (onClose case final close?)
          CloseButton(key: const ValueKey('member-close'), onPressed: close),
      ],
      bottom: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: [
          for (final (id, label, _) in tabs)
            Tab(key: ValueKey('member-tab-$id'), text: label),
        ],
      ),
    );
    // #3891 — the bar then the body, stated: by reading order a body
    // scrolled up would come before the bar its Tab cycle starts with.
    return DefaultTabController(
      length: tabs.length,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Scaffold(
        key: const ValueKey('member-record'),
        appBar: PreferredSize(
          preferredSize: bar.preferredSize,
          child: FocusTraversalOrder(
            order: const NumericFocusOrder(1),
            child: bar,
          ),
        ),
        // A member the reader cannot read, or none of that id, is said in
        // words; nothing is shown as if it were theirs.
        body: FocusTraversalOrder(
          order: const NumericFocusOrder(2),
          child: members != null && member == null
              ? Center(
                  child: Text(
                    l.searchRecordUnreadable,
                    key: const ValueKey('search-record-unreadable'),
                  ),
                )
              : TabBarView(children: [for (final (_, _, body) in tabs) body]),
        ),
      ),
    ));
  }
}

/// The member's bookings among those read (this month and the last), the
/// latest first; one opens its detail.
class _Bookings extends ConsumerWidget {
  const _Bookings({required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final format = appFormatOf(context);
    final visits = ref.watch(membersVisitsProvider);
    final read = visits.reservations;
    if (read == null) return const SizedBox.shrink();
    final targets =
        ref.watch(targetNamesProvider).value ??
        const {}; // empty-ok: an unread place name shows blank
    final now = ref.watch(clockProvider).now();
    final mine = [
      for (final r in read)
        if (r.memberId == memberId) r,
    ]..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    if (mine.isEmpty) {
      return Center(
        child: Text(
          l.memberBookingsNone(
            format.dates(DateShape.numeric).format(visits.since),
          ),
          key: const ValueKey('member-bookings-none'),
        ),
      );
    }
    return ListView(
      key: const ValueKey('member-bookings'),
      children: [
        for (final r in mine)
          ListTile(
            key: ValueKey('member-booking-${r.id}'),
            title: Text(r.spaceNameFrom(targets)),
            subtitle: Text(
              format.dates(DateShape.weekdayDate).format(r.startsAt),
            ),
            trailing:
                r.startsAt.isAfter(now) ||
                    r.status == ReservationStatus.cancelled
                ? null
                : const Icon(Icons.check_circle_outline),
            onTap: () => showReservationDetail(context, ref, r),
          ),
      ],
    );
  }
}

/// Notes with the member: write one, or open the conversation.
class _Notes extends ConsumerWidget {
  const _Notes({required this.member, required this.name});

  final Member member;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return ListView(
      padding: AppSpacing.lgAll,
      children: [
        ListTile(
          key: const ValueKey('member-notes-write'),
          leading: const Icon(Icons.edit_note),
          title: Text(l.memberNotesWrite),
          onTap: () => showMemberNoteDialog(
            context,
            ref,
            toMemberId: member.id,
            recipientName: name,
          ),
        ),
        ListTile(
          key: const ValueKey('member-notes-conversation'),
          leading: const Icon(Icons.chat_bubble_outline),
          title: Text(l.messagesTitle),
          onTap: () =>
              openDirectConversation(context, ref, memberId: member.id),
        ),
      ],
    );
  }
}

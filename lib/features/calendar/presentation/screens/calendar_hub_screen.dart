// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/calendar/calendar_item.dart';
import '../../../../core/help/help_hint.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../money/domain/invoice_ubl.dart';
import '../../../money/presentation/widgets/invoice_detail_sheet.dart';
import '../../../money/domain/money_face.dart';
import '../../../money/providers/money_face_controller.dart';
import '../../../money/providers/money_focus_controller.dart';
import '../../../money/providers/money_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../../workspace/presentation/screens/inbox_screen.dart';
import '../../../workspace/presentation/widgets/conversation_avatar.dart';
import '../../../workspace/presentation/widgets/conversation_thread.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../providers/calendar_providers.dart';
import '../widgets/calendar_item_row.dart';

/// THE CALENDAR HUB (#718): the dated view of everything.
///
/// THE CALENDAR IS A SELECTOR, NOT A STAGE. A month grid pinned in the
/// middle of the screen answered one question — "when is my next
/// booking?" — and nothing else that has a date: the alert that needs
/// your confirmation, the message from this morning, the invoice issued
/// last week, the payment that landed, the reminder due in an hour. Here
/// the date is picked (one day, or a range) and the screen is the FEED:
/// one list, grouped by day, every dated fact the member may see,
/// filtered by kind, each row opening its source.
///
/// WHOSE. Your own by default. A member with the finance or member
/// permission can switch to another member and sees exactly what the
/// server allows for THAT member — reservations and alerts as before,
/// messages only from conversations the viewer is also in, money only
/// under `may_view_member_finances()`. A kind the server declines comes
/// back LOCKED and is shown as such, never as an empty list that reads
/// like "nothing happened". Reading another member's money is logged
/// server-side, and the ⓘ opens who can see what — and who did.
class CalendarHubScreen extends ConsumerStatefulWidget {
  const CalendarHubScreen({super.key});

  @override
  ConsumerState<CalendarHubScreen> createState() => _CalendarHubScreenState();
}

class _CalendarHubScreenState extends ConsumerState<CalendarHubScreen> {
  late DateTime _from;
  late DateTime _to;
  bool _range = false;
  Set<CalendarKind>? _kinds;
  String? _memberId;

  @override
  void initState() {
    super.initState();
    final today = WorkspaceTime.dateOf(ref.read(clockProvider).now());
    _from = today;
    _to = today;
  }

  /// Half-open UTC bounds of the selected local day(s), anchored in the
  /// workspace clock like every booking window (#490).
  CalendarQuery get _query => CalendarQuery(
        from: WorkspaceTime.at(_from.year, _from.month, _from.day).toUtc(),
        to: WorkspaceTime.at(_to.year, _to.month, _to.day + 1).toUtc(),
        kinds: _kinds,
        memberId: _memberId,
      );

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(_from.year - 3),
      lastDate: DateTime(_from.year + 3),
    );
    if (picked != null) setState(() => _from = _to = picked);
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _from, end: _to),
      firstDate: DateTime(_from.year - 3),
      lastDate: DateTime(_from.year + 3),
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
    }
  }

  void _shift(int days) => setState(() {
        final span = _to.difference(_from).inDays + 1;
        _from = _from.add(Duration(days: days * span));
        _to = _to.add(Duration(days: days * span));
      });

  /// Every row leads somewhere (#718): the reservation sheet, the
  /// conversation, the alert, the invoice, the month on the Money tab.
  Future<void> _open(CalendarItem item) async {
    switch (item.link) {
      case ReservationLink(:final id):
        context.push('/res/$id');
      case ConversationLink(:final id):
        await showConversationThread(context, ref, conversationId: id);
      case EventLink():
        openInbox(ref, InboxTab.alerts);
        context.go('/messages');
      case LedgerLink(:final period):
        // #720 — a payment lands on the Payments face of that month.
        ref.read(moneyFaceControllerProvider.notifier).show(MoneyFace.payments);
        ref.read(moneyFocusControllerProvider.notifier).setPeriod(period);
        context.go('/money');
      case InvoiceLink(:final id):
        final invoices = await ref.read(invoicesProvider.future);
        final invoice = invoices.where((i) => i.id == id).firstOrNull;
        if (invoice == null || !mounted) return;
        final matches = ref.read(invoiceMatchesProvider).value ?? const {};
        final country = ref.read(currentWorkspaceProvider).value?.countryCode ?? '';
        await showInvoiceDetailSheet(
          context,
          invoice: invoice,
          match: matches[invoice.id],
          canIssue: ref
              .read(myPermissionsProvider)
              .contains(WorkspacePermission.issueInvoices),
          isEu: isEuCountry(country),
        );
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final format = ref.watch(appFormatProvider);
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final me = ref.watch(myMemberProvider).value;
    final permissions = ref.watch(myPermissionsProvider);
    // Looking at OTHER members is a permission, not a role: finances or
    // member administration. The server re-checks per kind anyway.
    final mayPickMember = permissions.contains(WorkspacePermission.viewFinances) ||
        permissions.contains(WorkspacePermission.manageMembers);
    final page = ref.watch(calendarItemsProvider(_query));

    return Scaffold(
      body: Column(children: [
        const HelpHint(HelpHintId.calendar),
        // ── the selector ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(children: [
            IconButton(
              key: const ValueKey('calendar-prev'),
              tooltip: l10n?.calendarPrevious ?? 'Previous',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _shift(-1),
            ),
            Expanded(
              child: TextButton(
                key: const ValueKey('calendar-date-button'),
                onPressed: _range ? _pickRange : _pickDay,
                child: Text(
                  _range && !_from.isAtSameMomentAs(_to)
                      ? '${format.shortDate(_from)} – ${format.shortDate(_to)}'
                      : format.date(_from),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('calendar-next'),
              tooltip: l10n?.calendarNext ?? 'Next',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _shift(1),
            ),
            SegmentedButton<bool>(
              key: const ValueKey('calendar-range-toggle'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.today_outlined),
                  tooltip: l10n?.calendarDay ?? 'Day',
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.date_range_outlined),
                  tooltip: l10n?.calendarRange ?? 'Range',
                ),
              ],
              selected: {_range},
              onSelectionChanged: (s) => setState(() {
                _range = s.first;
                if (!_range) _to = _from;
              }),
            ),
          ]),
        ),
        // ── the filters ───────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(children: [
            FilterChip(
              key: const ValueKey('calendar-kind-all'),
              label: Text(l10n?.eventsFilterAll ?? 'All'),
              selected: _kinds == null,
              onSelected: (_) => setState(() => _kinds = null),
            ),
            for (final kind in CalendarKind.values) ...[
              const SizedBox(width: AppSpacing.xs),
              FilterChip(
                key: ValueKey('calendar-kind-${kind.wire}'),
                avatar: Icon(calendarKindIcon(kind), size: 18),
                label: Text(calendarKindLabel(l10n, kind)),
                selected: _kinds?.contains(kind) ?? false,
                onSelected: (on) => setState(() {
                  final next = {...?_kinds};
                  on ? next.add(kind) : next.remove(kind);
                  _kinds = next.isEmpty ? null : next;
                }),
              ),
            ],
            if (mayPickMember) ...[
              const SizedBox(width: AppSpacing.sm),
              // Another member's dated facts — as far as the server lets
              // THIS viewer see them.
              ActionChip(
                key: const ValueKey('calendar-member-chip'),
                avatar: const Icon(Icons.person_search_outlined, size: 18),
                label: Text(
                  _memberId == null
                      ? (l10n?.calendarMemberMe ?? 'Me')
                      : (names[_memberId] ?? ''),
                ),
                onPressed: () => _pickMember(names, me?.id),
              ),
            ],
          ]),
        ),
        // ── the feed ──────────────────────────────────────────────
        Expanded(
          child: switch (page) {
            AsyncData(:final value) => _feed(context, value, names, format),
            AsyncError() => Center(
                child: Text(
                  l10n?.workspaceGenericError ??
                      'Something went wrong. Please try again.',
                ),
              ),
            _ => const LoadingView(),
          },
        ),
      ]),
    );
  }

  Widget _feed(
    BuildContext context,
    CalendarPage page,
    Map<String, String> names,
    dynamic format,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (page.items.isEmpty && page.locked.isEmpty) {
      return EmptyState(
        icon: Icons.event_available_outlined,
        title: l10n?.calendarNothingHere ?? 'Nothing on these dates.',
      );
    }
    // Grouped by WORKSPACE day: a message at 23:30 Paris belongs to that
    // evening whatever the reader's device says.
    final byDay = <DateTime, List<CalendarItem>>{};
    for (final item in page.items) {
      final day = WorkspaceTime.dateOf(item.at);
      byDay.putIfAbsent(day, () => []).add(item);
    }
    final days = byDay.keys.toList()..sort();
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(calendarItemsProvider),
      child: ListView(
        key: const ValueKey('calendar-feed'),
        children: [
          // Locked kinds say so, up front (#718): an admin who may not
          // read a member's messages is told, not shown an empty day.
          if (page.locked.isNotEmpty)
            Padding(
              padding: AppSpacing.mdAll,
              child: Row(children: [
                Icon(Icons.lock_outline, size: 18,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n?.calendarLockedKinds(
                          page.locked.map((k) => calendarKindLabel(l10n, k)).join(', '),
                        ) ??
                        'Not visible to you for this member: '
                            '${page.locked.map((k) => calendarKindLabel(l10n, k)).join(', ')}',
                    key: const ValueKey('calendar-locked'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ]),
            ),
          for (final day in days) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
              child: Text(
                format.shortDate(WorkspaceTime.at(day.year, day.month, day.day, 12)),
                style: theme.textTheme.titleSmall,
              ),
            ),
            for (final item in byDay[day]!)
              CalendarItemRow(
                item: item,
                memberName: names[item.memberId] ?? '',
                onTap: () => _open(item),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickMember(Map<String, String> names, String? myId) async {
    final l10n = AppLocalizations.of(context);
    final entries = names.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    final picked = await showModalBottomSheet<String?>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(children: [
          ListTile(
            key: const ValueKey('calendar-member-me'),
            leading: const Icon(Icons.person_outline),
            title: Text(l10n?.calendarMemberMe ?? 'Me'),
            onTap: () => Navigator.of(context).pop(myId),
          ),
          for (final e in entries)
            if (e.key != myId)
              ListTile(
                key: ValueKey('calendar-member-${e.key}'),
                leading: MemberAvatarByMember(memberId: e.key, name: e.value),
                title: Text(e.value),
                onTap: () => Navigator.of(context).pop(e.key),
              ),
        ]),
      ),
    );
    if (picked == null) return;
    setState(() => _memberId = picked == myId ? null : picked);
  }
}

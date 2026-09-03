// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../workspace/presentation/widgets/note_record_open.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/calendar/calendar_item.dart';
import '../../../../core/help/help_hint.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../money/domain/invoice_ubl.dart';
import '../../../money/presentation/widgets/invoice_detail_sheet.dart';
import '../../../money/domain/money_face.dart';
import '../../../money/providers/money_face_controller.dart';
import '../../../money/providers/money_focus_controller.dart';
import '../../../money/providers/money_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../../workspace/presentation/screens/inbox_screen.dart';
import '../../../workspace/presentation/widgets/conversation_avatar.dart';
import '../../../workspace/presentation/widgets/conversation_thread.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../providers/calendar_providers.dart';
import '../calendar_view.dart';
import '../widgets/calendar_feed.dart';
import '../widgets/calendar_kind_chips.dart';
import '../widgets/calendar_month_grid.dart';
import '../widgets/calendar_week_strip.dart';

/// THE CALENDAR HUB (#718): the dated view of everything.
///
/// THE CALENDAR IS A SELECTOR, NOT A STAGE. The date is picked and the
/// screen is the FEED: one list, grouped by day, every dated fact the
/// member may see, filtered by kind, each row opening its source.
///
/// #818 — three ways to pick: the AGENDA (from today forward, the next
/// thirty days — the question most people bring), the WEEK (a strip of
/// seven pills with markers and counts) and the MONTH (a compact grid
/// with markers, today ringed, closed days muted). The arrows step by
/// the view, Today jumps back, and the feed names its days relatively.
/// With `calendarViews` off the hub keeps the plain day/range selector.
///
/// WHOSE. Your own by default. A member with the finance or member
/// permission can switch to another member and sees exactly what the
/// server allows for THAT member; a kind the server declines comes back
/// LOCKED and is shown as such (#719).
class CalendarHubScreen extends ConsumerStatefulWidget {
  const CalendarHubScreen({super.key});

  @override
  ConsumerState<CalendarHubScreen> createState() => _CalendarHubScreenState();
}

class _CalendarHubScreenState extends ConsumerState<CalendarHubScreen> {
  // ── the plain selector (flag off) ─────────────────────────────────
  late DateTime _from;
  late DateTime _to;
  bool _range = false;

  // ── the views (flag on, #818) ─────────────────────────────────────
  late CalendarSelection _selection;

  Set<CalendarKind>? _kinds;
  String? _memberId;

  DateTime get _today => WorkspaceTime.dateOf(ref.read(clockProvider).now());

  @override
  void initState() {
    super.initState();
    final today = _today;
    _from = today;
    _to = today;
    _selection = CalendarSelection(view: CalendarView.agenda, anchor: today);
  }

  bool get _viewsOn => ref
      .watch(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.calendarViews);

  /// #843 — decisions on the timeline. Off, the chip is gone and the
  /// query never asks for the kind, so the server sends none.
  bool get _validationsOn => ref
      .watch(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.calendarValidations);

  /// The kinds to ask for: null means "everything the workspace offers",
  /// which is not the same as everything the server knows.
  Set<CalendarKind>? get _askedKinds {
    if (_kinds != null) return _kinds;
    if (_validationsOn) return null;
    return CalendarKind.values.toSet()..remove(CalendarKind.validation);
  }

  /// Half-open UTC bounds of the plain selection, anchored in the
  /// workspace clock like every booking window (#490).
  CalendarQuery get _plainQuery => CalendarQuery(
        from: WorkspaceTime.at(_from.year, _from.month, _from.day).toUtc(),
        to: WorkspaceTime.at(_to.year, _to.month, _to.day + 1).toUtc(),
        kinds: _askedKinds,
        memberId: _memberId,
      );

  /// The views' query: the agenda's thirty days, the whole week, or the
  /// WHOLE month (one fetch feeds both the markers and the selected day).
  CalendarQuery get _viewQuery {
    final s = _selection;
    final bounds = s.view == CalendarView.month
        ? s.utcBounds(from: s.monthStart, to: s.monthEnd)
        : s.utcBounds();
    return CalendarQuery(
      from: bounds.from,
      to: bounds.to,
      kinds: _askedKinds,
      memberId: _memberId,
    );
  }

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

  Future<void> _jump() async {
    final anchor = _selection.anchor;
    final picked = await showDatePicker(
      context: context,
      initialDate: anchor,
      firstDate: DateTime(anchor.year - 3),
      lastDate: DateTime(anchor.year + 3),
    );
    if (picked != null) {
      setState(() => _selection = _selection.withAnchor(picked));
    }
  }

  /// Every row leads somewhere (#718): the reservation sheet, the
  /// conversation, the alert, the invoice, the month on the Money tab.
  Future<void> _open(CalendarItem item) async {
    switch (item.link) {
      case ReservationLink(:final id):
        context.push('/res/$id');
      case ConversationLink(:final id):
        await showConversationThread(context, ref, conversationId: id);
      case EventLink(:final id):
        // #843 — a validation row promised a decision, so it opens the
        // trail, not the feed the alert lives in.
        if (item.kind == CalendarKind.validation) {
          await showValidationTrailSheet(context, eventId: id);
          return;
        }
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
        final country =
            ref.read(currentWorkspaceProvider).value?.countryCode ?? '';
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
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final me = ref.watch(myMemberProvider).value;
    final permissions = ref.watch(myPermissionsProvider);
    // Looking at OTHER members is a permission, not a role: finances or
    // member administration. The server re-checks per kind anyway.
    final mayPickMember =
        permissions.contains(WorkspacePermission.viewFinances) ||
            permissions.contains(WorkspacePermission.manageMembers);
    final viewsOn = _viewsOn;
    final page = ref.watch(calendarItemsProvider(viewsOn ? _viewQuery : _plainQuery));

    final chips = CalendarKindChips(
      kinds: _kinds,
      // #843 — a workspace that does not want decisions on its timeline
      // is not offered the chip either.
      offered: [
        for (final kind in CalendarKind.values)
          if (kind != CalendarKind.validation || _validationsOn) kind,
      ],
      onKinds: (next) => setState(() => _kinds = next),
      memberLabel: !mayPickMember
          ? null
          : _memberId == null
              ? (l10n?.calendarMemberMe ?? 'Me')
              : (names[_memberId] ?? ''),
      onPickMember: () => _pickMember(names, me?.id),
    );
    final feed = switch (page) {
      AsyncData(:final value) => viewsOn
          ? _viewFeed(context, value, names)
          : CalendarFeed(
              page: value,
              names: names,
              onOpen: _open,
              onRefresh: () async => ref.invalidate(calendarItemsProvider),
            ),
      AsyncError() => Center(
          child: Text(
            l10n?.workspaceGenericError ??
                'Something went wrong. Please try again.',
          ),
        ),
      _ => const LoadingView(),
    };

    if (!viewsOn) {
      return Scaffold(
        body: Column(children: [
          const HelpHint(HelpHintId.calendar),
          _plainSelector(l10n),
          chips,
          Expanded(child: feed),
        ]),
      );
    }

    final selector = Column(mainAxisSize: MainAxisSize.min, children: [
      _viewBar(l10n),
      _stepBar(l10n),
      if (_selection.view != CalendarView.agenda) ...[
        _picker(page.value),
        const CalendarLegend(showClosed: true),
      ],
    ]);
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final landscape = constraints.maxWidth > constraints.maxHeight &&
            _selection.view != CalendarView.agenda;
        if (landscape) {
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: (constraints.maxWidth * 0.42).clamp(300.0, 460.0),
              child: SingleChildScrollView(
                child: Column(children: [
                  const HelpHint(HelpHintId.calendar),
                  selector,
                  chips,
                ]),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: feed),
          ]);
        }
        return Column(children: [
          const HelpHint(HelpHintId.calendar),
          selector,
          chips,
          Expanded(child: feed),
        ]);
      }),
    );
  }

  // ── flag OFF: the plain selector ───────────────────────────────────
  Widget _plainSelector(AppLocalizations? l10n) {
    final format = ref.watch(appFormatProvider);
    return Padding(
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
    );
  }

  // ── flag ON: the views ─────────────────────────────────────────────
  Widget _viewBar(AppLocalizations? l10n) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, 0),
        child: Row(children: [
          Expanded(
            child: SegmentedButton<CalendarView>(
              key: const ValueKey('calendar-view-switch'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: CalendarView.agenda,
                  icon: const Icon(Icons.view_agenda_outlined),
                  label: Text(l10n?.calendarViewAgenda ?? 'Agenda'),
                ),
                ButtonSegment(
                  value: CalendarView.week,
                  icon: const Icon(Icons.view_week_outlined),
                  label: Text(l10n?.calendarViewWeek ?? 'Week'),
                ),
                ButtonSegment(
                  value: CalendarView.month,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(l10n?.calendarViewMonth ?? 'Month'),
                ),
              ],
              selected: {_selection.view},
              onSelectionChanged: (s) =>
                  setState(() => _selection = _selection.withView(s.first)),
            ),
          ),
          IconButton(
            key: const ValueKey('calendar-today'),
            tooltip: l10n?.calendarToday ?? 'Today',
            icon: const Icon(Icons.today_outlined),
            onPressed: () =>
                setState(() => _selection = _selection.withAnchor(_today)),
          ),
        ]),
      );

  /// The arrows and the label of what is on screen: "Next 30 days · from
  /// 2 Sep", "1 – 7 Sep", "September 2026". The label opens a date
  /// picker that jumps the anchor.
  Widget _stepBar(AppLocalizations? l10n) {
    final format = ref.watch(appFormatProvider);
    final s = _selection;
    final label = switch (s.view) {
      CalendarView.agenda =>
        '${l10n?.calendarAgendaRange(calendarAgendaDays) ?? 'Next $calendarAgendaDays days'}'
            ' · ${format.shortDate(WorkspaceTime.at(s.anchor.year, s.anchor.month, s.anchor.day, 12))}',
      CalendarView.week => () {
          final end = DateTime(s.weekStart.year, s.weekStart.month, s.weekStart.day + 6);
          return '${format.shortDate(WorkspaceTime.at(s.weekStart.year, s.weekStart.month, s.weekStart.day, 12))}'
              ' – ${format.shortDate(WorkspaceTime.at(end.year, end.month, end.day, 12))}';
        }(),
      CalendarView.month => DateFormat.yMMMM(format.locale).format(s.anchor),
    };
    return Row(children: [
      IconButton(
        key: const ValueKey('calendar-prev'),
        tooltip: l10n?.calendarPrevious ?? 'Previous',
        icon: const Icon(Icons.chevron_left),
        onPressed: () => setState(() => _selection = _selection.shifted(-1)),
      ),
      Expanded(
        child: TextButton(
          key: const ValueKey('calendar-date-button'),
          onPressed: _jump,
          child: Text(label, overflow: TextOverflow.ellipsis),
        ),
      ),
      IconButton(
        key: const ValueKey('calendar-next'),
        tooltip: l10n?.calendarNext ?? 'Next',
        icon: const Icon(Icons.chevron_right),
        onPressed: () => setState(() => _selection = _selection.shifted(1)),
      ),
    ]);
  }

  bool Function(DateTime day)? get _isDayOpen {
    final weekdays = ref.watch(openWeekdaysProvider).value;
    final closures = ref.watch(closureDaysProvider).value;
    if (weekdays == null || closures == null) return null;
    return (day) =>
        weekdays.contains(day.weekday) &&
        !closures.any((c) =>
            c.day.year == day.year &&
            c.day.month == day.month &&
            c.day.day == day.day);
  }

  /// The month grid or the week strip, fed by the page's markers.
  Widget _picker(CalendarPage? page) {
    final groups = <DateTime, Set<CalendarGroup>>{};
    final counts = <DateTime, int>{};
    for (final item in page?.items ?? const <CalendarItem>[]) {
      final d = WorkspaceTime.dateOf(item.at);
      final day = DateTime(d.year, d.month, d.day);
      groups.putIfAbsent(day, () => {}).add(item.kind.group);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    final format = ref.watch(appFormatProvider);
    final s = _selection;
    return switch (s.view) {
      CalendarView.month => CalendarMonthGrid(
          month: s.monthStart,
          selectedDay: s.anchor,
          today: _today,
          groupsByDay: groups,
          isDayOpen: _isDayOpen,
          locale: format.locale,
          onSelect: (day) =>
              setState(() => _selection = _selection.withAnchor(day)),
        ),
      CalendarView.week => CalendarWeekStrip(
          weekStart: s.weekStart,
          selectedDay: s.anchor,
          today: _today,
          groupsByDay: groups,
          countsByDay: counts,
          isDayOpen: _isDayOpen,
          locale: format.locale,
          onSelect: (day) =>
              setState(() => _selection = _selection.withAnchor(day)),
        ),
      CalendarView.agenda => const SizedBox.shrink(),
    };
  }

  /// The feed the view serves: the whole agenda or week, or the one
  /// selected day of the month (from the month's page).
  Widget _viewFeed(
    BuildContext context,
    CalendarPage page,
    Map<String, String> names,
  ) {
    final l10n = AppLocalizations.of(context);
    final s = _selection;
    final CalendarPage shown;
    final List<DateTime> days;
    final String empty;
    switch (s.view) {
      case CalendarView.agenda:
        shown = page;
        days = [
          for (var i = 0; i < calendarAgendaDays; i++)
            DateTime(s.anchor.year, s.anchor.month, s.anchor.day + i),
        ];
        empty = l10n?.calendarAgendaEmpty(calendarAgendaDays) ??
            'Nothing planned in the next $calendarAgendaDays days.';
      case CalendarView.week:
        shown = page;
        days = [
          for (var i = 0; i < 7; i++)
            DateTime(s.weekStart.year, s.weekStart.month, s.weekStart.day + i),
        ];
        empty = l10n?.calendarWeekEmpty ?? 'Nothing this week.';
      case CalendarView.month:
        shown = CalendarPage(
          subjectMemberId: page.subjectMemberId,
          locked: page.locked,
          items: [
            for (final item in page.items)
              if (DateUtils.isSameDay(WorkspaceTime.dateOf(item.at), s.anchor))
                item,
          ],
        );
        days = [s.anchor];
        empty = l10n?.calendarDayEmpty ?? 'Nothing on this day.';
    }
    // The agenda and the week list only the days that carry something
    // (or are closed); the month's single day always shows its header.
    return CalendarFeed(
      page: shown,
      names: names,
      onOpen: _open,
      onRefresh: () async => ref.invalidate(calendarItemsProvider),
      view: s.view,
      today: _today,
      days: days,
      closures: ref.watch(closureDaysProvider).value ?? const [],
      openWeekdays: ref.watch(openWeekdaysProvider).value,
      relative: true,
      coloured: true,
      emptyTitle: empty,
    );
  }

  // ── the filters ────────────────────────────────────────────────────
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

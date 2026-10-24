// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2553 -- My reservations: a person's own bookings on every workspace
// host their account names (C2), in the window they chose, merged by
// start, grouped by each workspace's own day, one more page at a time;
// a host that fails is said beside the others with its own Try again. The
// body of the personal data hub's reservations view; the hub mounts it.
//
// C3: Upcoming, Past (its own period, newest first) and Cancelled by the
// bookings' actual status; one source shown alone; each row's View, Check
// in and Cancel go to the host the row was read from (my_reservation_card).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/refusal_text.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/my_reservations.dart';
import '../../domain/my_reservations_composition.dart';
import '../../domain/reservation.dart';
import '../../providers/reservation_providers.dart';
import 'my_reservation_card.dart';

/// How far either way the period picker lets a person browse, in years:
/// a navigation bound of the dialog, not a limit on what the host answers.
const int _pickerYears = 10;

class MyReservationsBody extends ConsumerWidget {
  const MyReservationsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(myReservationsFilterControllerProvider);
    final past = filter.tab == MyReservationsTab.past;
    final window = past
        ? ref.watch(myPastReservationsWindowControllerProvider)
        : ref.watch(myReservationsWindowControllerProvider);
    return switch (window) {
      AsyncData(:final value) => _Feed(window: value, filter: filter),
      AsyncError(:final error) => _Problem(
          text: problemWords(context.l10n, error),
          onRetry: () => past
              ? ref.invalidate(myPastReservationsWindowControllerProvider)
              : ref.invalidate(myReservationsWindowControllerProvider),
        ),
      _ => const LoadingView(),
    };
  }
}

/// The sentence for a read that answered nothing usable: the typed
/// refusal's own words, a refusal every surface knows, else the plain
/// failure.
String problemWords(AppLocalizations l10n, Object error) => switch (error) {
      MyReservationsRefused(:final failure) => switch (failure) {
          MyReservationsFailure.unsupported => l10n.myReservationsUnsupported,
          MyReservationsFailure.forbidden => l10n.myReservationsForbidden,
          MyReservationsFailure.invalid => l10n.myReservationsInvalid,
          MyReservationsFailure.misconfigured => l10n.myReservationsMisconfigured,
          MyReservationsFailure.malformed ||
          MyReservationsFailure.incompatible =>
            l10n.myReservationsMalformed,
          MyReservationsFailure.noContext => l10n.myReservationsNoWorkspace,
          MyReservationsFailure.hostUnavailable =>
            l10n.myReservationsHostUnavailable,
          MyReservationsFailure.gone => l10n.myReservationsGone,
        },
      TimeoutException() => l10n.myReservationsTimedOut,
      _ => knownRefusalText(l10n, error) ?? l10n.myReservationsFailed,
    };

class _Feed extends ConsumerWidget {
  const _Feed({required this.window, required this.filter});

  final MyReservationsWindow window;
  final MyReservationsFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final query = MyReservationsQuery(
      from: window.from,
      to: window.to,
      direction: filter.tab.direction,
    );
    final composed = ref.watch(myReservationsComposerProvider(query));
    final loaded = composed.value;
    final Widget body;
    if (loaded != null) {
      final shown = MyReservationsSelection(
        loaded,
        tab: filter.tab,
        source: filter.source,
        now: ref.watch(clockProvider).now(),
      );
      body = shown.empty
          ? EmptyState(
              key: const ValueKey('my-reservations-empty'),
              icon: Icons.event_busy_outlined,
              title: l10n.myReservationsEmpty,
            )
          : _List(query: query, composition: loaded, shown: shown);
    } else if (composed.hasError) {
      body = _Problem(
        text: problemWords(l10n, composed.error!),
        onRetry: () =>
            ref.invalidate(myReservationsComposerProvider(query)),
      );
    } else {
      body = const LoadingView();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WindowHeader(window: window, past: filter.tab == MyReservationsTab.past),
        _Filters(filter: filter, sources: loaded?.slots ?? const []),
        Expanded(child: body),
      ],
    );
  }
}

/// The period shown, the way to change it and its ceiling in words.
class _WindowHeader extends ConsumerWidget {
  const _WindowHeader({required this.window, required this.past});

  final MyReservationsWindow window;

  /// The Past tab's own period is the one shown and changed.
  final bool past;

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(window.from.year - _pickerYears),
      lastDate: DateTime(window.from.year + _pickerYears, 12, 31),
      initialDateRange: DateTimeRange(start: window.from, end: window.lastDay),
    );
    if (picked == null || !context.mounted) return;
    if (past) {
      ref
          .read(myPastReservationsWindowControllerProvider.notifier)
          .cover(picked.start, picked.end);
    } else {
      ref
          .read(myReservationsWindowControllerProvider.notifier)
          .cover(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = ref.watch(appFormatProvider);
    final theme = Theme.of(context);
    return Padding(
      padding: AppSpacing.gutterH,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            children: [
              Text(
                '${format.date(window.from)} – ${format.date(window.lastDay)}',
                style: theme.textTheme.titleMedium,
              ),
              TextButton.icon(
                key: const ValueKey('my-reservations-window'),
                onPressed: () => _pick(context, ref),
                icon: const Icon(Icons.date_range_outlined),
                label: Text(l10n.myReservationsChangePeriod),
              ),
            ],
          ),
          Text(
            l10n.myReservationsPeriodLimit(window.maxDays),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// The tabs, and the sources to show one alone when there are several.
class _Filters extends ConsumerWidget {
  const _Filters({required this.filter, required this.sources});

  final MyReservationsFilter filter;
  final List<MyReservationsSlot> sources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(myReservationsFilterControllerProvider.notifier);
    return Padding(
      padding: AppSpacing.gutterH,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final tab in MyReservationsTab.values)
                ChoiceChip(
                  key: ValueKey('my-reservations-tab-${tab.name}'),
                  label: Text(_tabWords(l10n, tab)),
                  selected: filter.tab == tab,
                  onSelected: (_) => controller.showTab(tab),
                ),
            ],
          ),
          if (sources.length > 1)
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                ChoiceChip(
                  key: const ValueKey('my-reservations-source-all'),
                  label: Text(l10n.myReservationsSourceAll),
                  selected: filter.source == null,
                  onSelected: (_) => controller.showSource(null),
                ),
                for (final slot in sources)
                  ChoiceChip(
                    key: ValueKey('my-reservations-source-${slot.installationId}'),
                    label: Text(_sourceName(l10n, slot)),
                    selected: filter.source == slot.installationId,
                    onSelected: (_) => controller.showSource(slot.installationId),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

String _sourceName(AppLocalizations l10n, MyReservationsSlot slot) {
  final labels = slot.source.labels;
  return labels.isEmpty ? l10n.myReservationsSourceUnnamed : labels.join(', ');
}

/// A tab's name.
String _tabWords(AppLocalizations l10n, MyReservationsTab tab) =>
    switch (tab) {
      MyReservationsTab.upcoming => l10n.myReservationsTabUpcoming,
      MyReservationsTab.past => l10n.myReservationsTabPast,
      MyReservationsTab.cancelled => l10n.myReservationsTabCancelled,
    };

/// A failure with the way to try again, in words.
class _Problem extends StatelessWidget {
  const _Problem({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.gutterAll,
      children: [
        InlineBanner(icon: Icons.error_outline, text: text),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const ValueKey('my-reservations-retry'),
            onPressed: onRetry,
            child: Text(context.l10n.commonRetry),
          ),
        ),
      ],
    );
  }
}

/// The bookings of every host that answered, merged by start and grouped
/// by each workspace's own calendar day; beside them, each host that is
/// still read, failed or cannot be reached, with its own Try again; and
/// the next page's button while a host says there is more.
class _List extends ConsumerWidget {
  const _List({required this.query, required this.composition, required this.shown});

  final MyReservationsQuery query;
  final MyReservationsComposition composition;
  final MyReservationsSelection shown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = ref.watch(appFormatProvider);
    final entries = shown.entries;
    final composer = ref.read(myReservationsComposerProvider(query).notifier);
    return ListView(
      key: const ValueKey('my-reservations-list'),
      padding: AppSpacing.gutterAll,
      children: [
        for (final slot in shown.slots)
          if (slot.state != MyReservationsSlotState.read)
            _SlotNotice(slot: slot, onRetry: () => composer.retry(slot.installationId)),
        for (final (i, e) in entries.indexed) ...[
          if (i == 0 || entries[i - 1].day != e.day)
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.xs,
              ),
              child: Text(
                DateFormat.yMMMEd(format.locale).format(e.day),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          MyReservationCard(
            key: ValueKey('my-reservation-row-${e.source}-${e.item.id}'),
            entry: e,
            query: query,
          ),
        ],
        for (final slot in shown.slots)
          if (slot.state == MyReservationsSlotState.read && slot.failure != null) ...[
            const SizedBox(height: AppSpacing.sm),
            InlineBanner(
              key: ValueKey('my-reservations-more-failed-${slot.installationId}'),
              icon: Icons.error_outline,
              text: problemWords(l10n, slot.failure!),
            ),
          ],
        if (shown.hasMore)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Center(
              child: FilledButton.tonal(
                key: const ValueKey('my-reservations-load-more'),
                onPressed: composition.loadingMore
                    ? null
                    : () => composer.loadMore(only: shown.source),
                child: Text(
                  composition.loadingMore
                      ? l10n.myReservationsLoadingMore
                      : l10n.myReservationsLoadMore,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One host that has not answered yet, or did not: its name, why, and the
/// way to ask it again. The other hosts' bookings stay beside it.
class _SlotNotice extends StatelessWidget {
  const _SlotNotice({required this.slot, required this.onRetry});

  final MyReservationsSlot slot;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = _sourceName(l10n, slot);
    final failure = slot.failure;
    if (slot.state == MyReservationsSlotState.reading || failure == null) {
      return Padding(
        key: ValueKey('my-reservations-source-reading-${slot.installationId}'),
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          l10n.myReservationsSourceReading(name),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return Padding(
      key: ValueKey('my-reservations-source-failed-${slot.installationId}'),
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InlineBanner(
            icon: Icons.cloud_off_outlined,
            text: l10n.myReservationsSourceProblem(name, problemWords(l10n, failure)),
          ),
          TextButton(
            key: ValueKey('my-reservations-source-retry-${slot.installationId}'),
            onPressed: onRetry,
            child: Text(l10n.commonRetry),
          ),
        ],
      ),
    );
  }
}

/// The icon of what a booking holds (#2554 C2 reuses it on the Overview).
IconData myReservationKindIcon(MyReservationPlaceKind kind) => switch (kind) {
      MyReservationPlaceKind.seat => Icons.chair_outlined,
      MyReservationPlaceKind.desk => Icons.desk_outlined,
      MyReservationPlaceKind.office => Icons.meeting_room_outlined,
      MyReservationPlaceKind.level => Icons.layers_outlined,
    };

/// What a booking holds, in words.
String myReservationKindWords(AppLocalizations l10n, MyReservationPlaceKind kind) =>
    switch (kind) {
      MyReservationPlaceKind.seat => l10n.myReservationsKindSeat,
      MyReservationPlaceKind.desk => l10n.myReservationsKindDesk,
      MyReservationPlaceKind.office => l10n.myReservationsKindOffice,
      MyReservationPlaceKind.level => l10n.myReservationsKindLevel,
    };

/// Where a booking stands, in words.
String myReservationStatusWords(AppLocalizations l10n, ReservationStatus status) =>
    switch (status) {
      ReservationStatus.reserved => l10n.myReservationsStatusReserved,
      ReservationStatus.checkedIn => l10n.myReservationsStatusCheckedIn,
      ReservationStatus.completed => l10n.myReservationsStatusCompleted,
      ReservationStatus.cancelled => l10n.myReservationsStatusCancelled,
      ReservationStatus.released => l10n.myReservationsStatusReleased,
    };

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2553 C1 -- My reservations: a person's own bookings on the selected
// workspace's host, in the window they chose, grouped by day, one more
// page at a time. The body of the personal data hub's reservations view;
// the hub mounts it. It changes nothing: viewing, cancelling and checking
// in keep their own captured workspace context.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../core/trace/refusal_text.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/my_reservations.dart';
import '../../domain/reservation.dart';
import '../../providers/reservation_providers.dart';

/// How far either way the period picker lets a person browse, in years:
/// a navigation bound of the dialog, not a limit on what the host answers.
const int _pickerYears = 10;

class MyReservationsBody extends ConsumerWidget {
  const MyReservationsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(myReservationsWindowControllerProvider);
    return switch (window) {
      AsyncData(:final value) => _Feed(window: value),
      AsyncError(:final error) => _Problem(
          text: problemWords(context.l10n, error),
          onRetry: () => ref.invalidate(myReservationsWindowControllerProvider),
        ),
      _ => const LoadingView(),
    };
  }
}

/// The sentence for a read that answered nothing usable: the typed
/// refusal's own words, a refusal every surface knows, else the plain
/// failure.
@visibleForTesting
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
        },
      _ => knownRefusalText(l10n, error) ?? l10n.myReservationsFailed,
    };

class _Feed extends ConsumerWidget {
  const _Feed({required this.window});

  final MyReservationsWindow window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final query = MyReservationsQuery(from: window.from, to: window.to);
    final feed = ref.watch(myReservationsFeedControllerProvider(query));
    final loaded = feed.value;
    final Widget body;
    if (loaded != null) {
      body = loaded.items.isEmpty && !loaded.hasMore
          ? EmptyState(
              key: const ValueKey('my-reservations-empty'),
              icon: Icons.event_busy_outlined,
              title: l10n.myReservationsEmpty,
            )
          : _List(query: query, feed: loaded);
    } else if (feed.hasError) {
      body = _Problem(
        text: problemWords(l10n, feed.error!),
        onRetry: () =>
            ref.invalidate(myReservationsFeedControllerProvider(query)),
      );
    } else {
      body = const LoadingView();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WindowHeader(window: window),
        Expanded(child: body),
      ],
    );
  }
}

/// The period shown, the way to change it and its ceiling in words.
class _WindowHeader extends ConsumerWidget {
  const _WindowHeader({required this.window});

  final MyReservationsWindow window;

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(window.from.year - _pickerYears),
      lastDate: DateTime(window.from.year + _pickerYears, 12, 31),
      initialDateRange: DateTimeRange(start: window.from, end: window.lastDay),
    );
    if (picked == null || !context.mounted) return;
    ref
        .read(myReservationsWindowControllerProvider.notifier)
        .cover(picked.start, picked.end);
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

/// The pages read so far, grouped by the workspace-clock day, and the next
/// page's button while the host says there is more.
class _List extends ConsumerWidget {
  const _List({required this.query, required this.feed});

  final MyReservationsQuery query;
  final MyReservationsFeed feed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = ref.watch(appFormatProvider);
    final items = feed.items;
    final failed = feed.loadMoreFailure;
    return ListView(
      key: const ValueKey('my-reservations-list'),
      padding: AppSpacing.gutterAll,
      children: [
        for (final (i, r) in items.indexed) ...[
          if (i == 0 ||
              WorkspaceTime.dateOf(items[i - 1].startsAt) !=
                  WorkspaceTime.dateOf(r.startsAt))
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.xs,
              ),
              child: Text(
                format.date(r.startsAt),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          _ReservationCard(item: r),
        ],
        if (failed != null) ...[
          const SizedBox(height: AppSpacing.sm),
          InlineBanner(icon: Icons.error_outline, text: problemWords(l10n, failed)),
        ],
        if (feed.hasMore)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Center(
              child: FilledButton.tonal(
                key: const ValueKey('my-reservations-load-more'),
                onPressed: feed.loadingMore
                    ? null
                    : () => ref
                        .read(myReservationsFeedControllerProvider(query).notifier)
                        .loadMore(),
                child: Text(
                  feed.loadingMore
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

class _ReservationCard extends ConsumerWidget {
  const _ReservationCard({required this.item});

  final MyReservationItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = ref.watch(appFormatProvider);
    final theme = Theme.of(context);
    final label = item.placeLabel.isEmpty
        ? l10n.myReservationsUnnamedPlace
        : item.placeLabel;
    final checkedIn = item.checkedInAt;
    final checkedOut = item.checkedOutAt;
    return Card(
      key: ValueKey('my-reservation-${item.id}'),
      child: Padding(
        padding: AppSpacing.lgAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_kindIcon(item.placeKind)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(label, style: theme.textTheme.titleMedium)),
                Text(_statusWords(l10n, item.status), style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('${format.time(item.startsAt)}–${format.time(item.endsAt)}'),
            Text(
              '${_kindWords(l10n, item.placeKind)} · ${item.workspaceName}',
              style: theme.textTheme.bodySmall,
            ),
            if (checkedIn != null)
              Text(
                l10n.myReservationsCheckedInAt(format.time(checkedIn)),
                style: theme.textTheme.bodySmall,
              ),
            if (checkedOut != null)
              Text(
                l10n.myReservationsCheckedOutAt(format.time(checkedOut)),
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

IconData _kindIcon(MyReservationPlaceKind kind) => switch (kind) {
      MyReservationPlaceKind.seat => Icons.chair_outlined,
      MyReservationPlaceKind.desk => Icons.desk_outlined,
      MyReservationPlaceKind.office => Icons.meeting_room_outlined,
      MyReservationPlaceKind.level => Icons.layers_outlined,
    };

String _kindWords(AppLocalizations l10n, MyReservationPlaceKind kind) =>
    switch (kind) {
      MyReservationPlaceKind.seat => l10n.myReservationsKindSeat,
      MyReservationPlaceKind.desk => l10n.myReservationsKindDesk,
      MyReservationPlaceKind.office => l10n.myReservationsKindOffice,
      MyReservationPlaceKind.level => l10n.myReservationsKindLevel,
    };

String _statusWords(AppLocalizations l10n, ReservationStatus status) =>
    switch (status) {
      ReservationStatus.reserved => l10n.myReservationsStatusReserved,
      ReservationStatus.checkedIn => l10n.myReservationsStatusCheckedIn,
      ReservationStatus.completed => l10n.myReservationsStatusCompleted,
      ReservationStatus.cancelled => l10n.myReservationsStatusCancelled,
      ReservationStatus.released => l10n.myReservationsStatusReleased,
    };

// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider, WidgetRef;
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/backend_settings.dart';
import '../../../core/backend/context_client_providers.dart';
import '../../../core/cache/cache_store.dart';
import '../../../core/files/file_saver.dart';
import '../../../core/instance/schema_compatibility.dart';
import '../../../core/privacy/recording_privacy.dart';
import '../../../core/privacy/recording_providers.dart';
import '../../../core/roles/audience_roles.dart';
import '../../../core/storage/booking_intent_store.dart';
import '../../../core/time/clock.dart';
import '../../../core/time/date_text.dart';
import '../../../core/trace/trace_logger.dart';
import '../../plan/providers/floor_plan_providers.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/booking_recovery.dart';
import '../application/save_calendar_file.dart';
import '../data/context_my_reservations_repository.dart';
import '../data/context_reservation_repository.dart';
import '../data/supabase_series_previewer.dart';
import '../domain/booking_intent.dart';
import '../domain/my_reservations.dart';
import '../domain/reservation.dart';
import '../domain/reservation_repository.dart';
import '../domain/series_preview.dart';

part 'reservation_providers.g.dart';

@Riverpod(keepAlive: true)
ReservationRepository reservationRepository(Ref ref) =>
    ContextReservationRepository(
      ref.watch(selectedWorkspaceClientProvider),
      ref.watch(cacheStoreProvider),
      // #2561 C1 — the window read runs on the workspace context and its
      // verified host's client; the other methods migrate with #2564.
      context: () => ref.read(workspaceContextProvider.future),
      clientFor: (id) => ref.read(workspaceClientProvider(id)),
    );

/// #2575 — which dates of a series would book, asked on the selected
/// workspace's own server before the person submits. Demo overrides it.
final seriesPreviewerProvider = Provider<SeriesPreviewer>(
  (ref) => SupabaseSeriesPreviewer(ref.watch(selectedWorkspaceClientProvider)),
);

/// #1855 — where a booking intent is valid: this account on this server.
/// Read at use, never captured: a later login or server switch reads its
/// own ledger. Tests and Demo override it with a fixed scope.
@riverpod
BookingIntentScope bookingIntentScope(Ref ref) {
  // #2564 O2 -- this account on the selected workspace's own host.
  final client = ref.watch(selectedWorkspaceClientProvider);
  return BookingIntentScope(
    account: client.auth.currentUser?.id ?? '',
    origin: client.rest.url,
  );
}

/// #1855 — the interrupted-booking command: durable intent, own-result
/// lookup, resume with the original request.
@riverpod
BookingRecovery bookingRecovery(Ref ref) => BookingRecovery(
  reservations: ref.watch(reservationRepositoryProvider),
  store: ref.watch(bookingIntentStoreProvider),
  scope: ref.watch(bookingIntentScopeProvider),
  clock: ref.watch(clockProvider),
  schemaVersion: requiredSchemaVersion,
);

/// #1855 — the bookings this device confirmed in the active workspace
/// whose answer it never read, oldest first. Empty is the normal state.
@riverpod
Future<List<BookingIntent>> unresolvedBookingIntents(Ref ref) async {
  // Watched before the await: a dependency registered on the far side of
  // the gap meets a disposed Ref (provider_watch_before_await lint).
  final recovery = ref.watch(bookingRecoveryProvider);
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return recovery.unresolved(workspaceId: workspace.id);
}

/// Reservations of the active workspace intersecting the given LOCAL day
/// (keyed 'yyyy-MM-dd'). Local, not UTC: the user thinks in wall-clock
/// days, and a UTC window shifts the visible day east/west of UTC (#119).
@riverpod
Future<List<Reservation>> reservationsForDay(Ref ref, String dayKey) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  final parts = dayKey.split('-').map(int.parse).toList();
  final from = DateTime(parts[0], parts[1], parts[2]);
  final to = DateTime(parts[0], parts[1], parts[2] + 1);
  return ref
      .watch(reservationRepositoryProvider)
      .fetchWindow(workspace.id, from: from, to: to);
}

/// My reserved (not yet checked-in) bookings starting within 7 days —
/// feeds the local check-in reminders (spec §4.3).
@riverpod
Future<List<Reservation>> myUpcomingReservations(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  final member = await ref.watch(myMemberProvider.future);
  if (workspace == null || member == null) return const [];
  final now = ref.read(clockProvider).now();
  final window = await ref.watch(reservationRepositoryProvider).fetchWindow(
        workspace.id,
        from: now,
        to: now.add(const Duration(days: 7)),
      );
  return window
      .where((r) =>
          r.memberId == member.id &&
          r.status == ReservationStatus.reserved &&
          r.startsAt.isAfter(now))
      .toList();
}

/// member id → display name for the active workspace.
@Riverpod(keepAlive: true)
Future<Map<String, String>> memberNames(Ref ref) async {
  // #1514 — the seam. Every name the plan, the calendar, the week grid
  // and the kiosk print comes through here, so while filming mode is on
  // none of them can print a real one. Watched BEFORE the gap (#1218).
  final recording = ref.watch(recordingPrivacyProvider);
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const {};
  final names =
      await ref.watch(workspaceRepositoryProvider).fetchMemberNames(workspace.id);
  if (!recording) return names;
  return {
    for (final entry in names.entries)
      entry.key: recordingName(entry.key, entry.value),
  };
}

/// Reservations of the active workspace intersecting the given LOCAL
/// month (keyed 'yyyy-MM'). See [reservationsForDay] for why local (#119):
/// a UTC key turned the July calendar into a June query east of UTC.
@riverpod
Future<List<Reservation>> reservationsForMonth(Ref ref, String monthKey) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  final parts = monthKey.split('-').map(int.parse).toList();
  final from = DateTime(parts[0], parts[1]);
  final to = DateTime(parts[0], parts[1] + 1);
  return ref
      .watch(reservationRepositoryProvider)
      .fetchWindow(workspace.id, from: from, to: to);
}

/// Canonical family key for [reservationsForMonth] — LOCAL wall-clock
/// month of [at], never UTC (#119).
String monthKeyOf(DateTime at) {
  final local = at.toLocal();
  return yearMonth(local.year, local.month);
}

/// Canonical family key for [reservationsForDay] — LOCAL wall-clock day.
String dayKeyOf(DateTime at) {
  return isoDay(at.toLocal());
}

/// The [reservationsForDay] keys a half-open window `[start, end)` touches —
/// one when it stays inside a device day, two when it straddles the local
/// midnight. A workspace-clock day window (day-based granularity) starts on
/// the previous device date when the device sits west of the workspace, so a
/// full-day booking lands under the OTHER key; a surface that reads only
/// `dayKeyOf(start)` misses it (the bug where a reservation showed on the
/// Plan tab but not the Reserve hub). Fetch both and merge.
@visibleForTesting
List<String> dayKeysForWindow(DateTime start, DateTime end) {
  final startKey = dayKeyOf(start);
  final endKey = dayKeyOf(end.subtract(const Duration(microseconds: 1)));
  return startKey == endKey ? [startKey] : [startKey, endKey];
}

/// Reservations overlapping the (possibly day-straddling) window,
/// fetched per day key and MERGED BY ID (maintainability audit: three
/// surfaces open-coded this merge and one skipped the dedup, double-
/// counting a booking that surfaces under both keys). Watches the day
/// providers, so callers rebuild when a day refreshes.
List<Reservation> reservationsAcrossWindow(
  WidgetRef ref,
  DateTime start,
  DateTime end,
) {
  final byId = <String, Reservation>{};
  for (final key in dayKeysForWindow(start, end)) {
    for (final r in ref.watch(reservationsForDayProvider(key)).value ??
        const <Reservation>[]) {
      byId[r.id] = r;
    }
  }
  return byId.values.toList();
}

/// #1848 — whether a day read of the window failed with nothing to show: such
/// a window is unavailable, never an empty one (drawing every seat free).
bool reservationsUnavailableAcrossWindow(
  WidgetRef ref,
  DateTime start,
  DateTime end,
) {
  var failed = false;
  for (final key in dayKeysForWindow(start, end)) {
    final read = ref.watch(reservationsForDayProvider(key));
    failed |= read.hasError && !read.hasValue;
  }
  return failed;
}

/// Reads the window's day keys again (the retry of an unavailable window).
void retryReservationsAcrossWindow(WidgetRef ref, DateTime start, DateTime end) {
  for (final key in dayKeysForWindow(start, end)) {
    ref.invalidate(reservationsForDayProvider(key));
  }
}

/// #1643 — the calendar-file command, wired to the seams it needs so the
/// button that asks for a file resolves no repository of its own.
///
/// The installation is the backend HOST: a reservation id is unique to a
/// backend, so the two together identify the booking wherever the file
/// is imported — and only a digest of them ever leaves the device.
///
/// Kept alive: the command holds closures that read providers through
/// this `ref` when the member taps Save, long after the preview future
/// completed — an auto-disposed provider would have thrown by then.
@Riverpod(keepAlive: true)
Future<CalendarFiles> calendarFiles(Ref ref) async {
  // Every watch before the first await, so a rebuild follows all of them.
  final reservations = ref.watch(reservationRepositoryProvider);
  final clock = ref.watch(clockProvider);
  final write = ref.watch(fileSaverProvider);
  final endpoint = await ref.watch(activeBackendProvider.future);
  final host = endpoint.host.trim();
  return CalendarFiles(
    reservations: reservations,
    clock: clock,
    installation: host.isEmpty ? 'deskilo' : host,
    targetNames: () => ref.read(targetNamesProvider.future),
    workspaceName: () async =>
        (await ref.read(currentWorkspaceProvider.future))?.name ?? '',
    write: write,
  );
}

/// #2575 -- the members another feature may name as an audience: the
/// workspace's member names. Put in the scope's overrides by the composition
/// root.
final audienceMembersFromReservations = audienceMembersProvider.overrideWith(
  (ref) => ref.watch(memberNamesProvider).value ?? const {},
);

/// #2578 — the place names a list of bookings shows (seat, office, level by
/// id), read from the plan once for the active workspace.
@riverpod
Future<Map<String, String>> bookingTargetNames(Ref ref) =>
    ref.watch(targetNamesProvider.future);

// #2578 — the reservations behind a capacity figure: every booking of the
// active workspace in the whole months [fromMonth, toMonth] on the local
// calendar, as the row policies let the reader see them.
/// The first day of `YYYY-MM`, or null when [month] is not one.
DateTime? _monthStart(String month) {
  final m = RegExp(r'^(\d{4})-(0[1-9]|1[0-2])$').firstMatch(month);
  return m == null
      ? null
      : DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!));
}

/// The bookings of the months, earliest first; empty for a malformed
/// period or a [toMonth] before [fromMonth].
@riverpod
Future<List<Reservation>> periodReservations(
  Ref ref,
  String fromMonth,
  String toMonth,
) async {
  final repository = ref.watch(reservationRepositoryProvider);
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  final from = _monthStart(fromMonth);
  final last = _monthStart(toMonth);
  if (workspace == null ||
      from == null ||
      last == null ||
      last.isBefore(from)) {
    return const [];
  }
  final to = DateTime(last.year, last.month + 1);
  final rows = await repository.fetchWindow(workspace.id, from: from, to: to);
  return [...rows]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
}

// #2553 C1 -- a person's own reservations on the selected workspace's host:
// the adapter over the context's verified client, the window the host's
// captured settings allow and the feed that pages through one window.

/// The read, bound to the workspace context at each call and to that
/// context's host client. Demo overrides it with the fixture's spaces.
@Riverpod(keepAlive: true)
MyReservationsRepository myReservationsRepository(Ref ref) =>
    ContextMyReservationsRepository(
      context: () => ref.read(workspaceContextProvider.future),
      clientFor: (id) => ref.read(workspaceClientProvider(id)),
    );

/// The window a person starts with and the longest one they may ask for:
/// the host's own settings as the context captured them, never a literal.
/// A registry without the rows fails typed.
@Riverpod(retry: myReservationsRetry)
class MyReservationsWindowController extends _$MyReservationsWindowController {
  @override
  Future<MyReservationsWindow> build() async {
    final now = ref.watch(clockProvider).now();
    final limits = await ref.watch(myReservationsRepositoryProvider).limits();
    return MyReservationsWindow.fromToday(
      now,
      defaultDays: limits.windowDays,
      maxDays: limits.maxDays,
    );
  }

  /// The person's choice of days, inclusive; cut to the ceiling.
  void cover(DateTime firstDay, DateTime lastDay) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.covering(firstDay, lastDay));
  }
}

/// What one feed holds: the pages read so far, where the next one starts,
/// whether a further page is being read and why the last one did not come.
class MyReservationsFeed {
  const MyReservationsFeed({
    required this.source,
    required this.items,
    required this.next,
    required this.hasMore,
    this.loadingMore = false,
    this.loadMoreFailure,
  });

  final String source;
  final List<MyReservationItem> items;
  final MyReservationsCursor? next;
  final bool hasMore;
  final bool loadingMore;

  /// The failure of the last "show more", kept beside the pages it follows
  /// so they stay on screen; null once a page came.
  final Object? loadMoreFailure;

  MyReservationsFeed _with({
    List<MyReservationItem>? items,
    MyReservationsCursor? next,
    bool? hasMore,
    required bool loadingMore,
    Object? loadMoreFailure,
  }) =>
      MyReservationsFeed(
        source: source,
        items: items ?? this.items,
        next: next ?? this.next,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore,
        loadMoreFailure: loadMoreFailure,
      );
}

/// The feed of one [MyReservationsQuery]: the first page on build, the next
/// ones appended by [loadMore]. A changed window is another query, so
/// another feed; a page that arrives for a disposed feed is dropped.
@Riverpod(retry: myReservationsRetry)
class MyReservationsFeedController extends _$MyReservationsFeedController {
  @override
  Future<MyReservationsFeed> build(MyReservationsQuery query) async {
    final page = await ref.watch(myReservationsRepositoryProvider).page(query);
    return MyReservationsFeed(
      source: page.source,
      items: page.items,
      next: page.next,
      hasMore: page.hasMore,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    final cursor = current?.next;
    if (current == null || cursor == null || !current.hasMore || current.loadingMore) {
      return;
    }
    state = AsyncData(current._with(loadingMore: true));
    try {
      final page = await ref
          .read(myReservationsRepositoryProvider)
          .page(query.continuedAfter(cursor));
      if (!ref.mounted) return;
      state = AsyncData(current._with(
        items: List.unmodifiable([...current.items, ...page.items]),
        next: page.next,
        hasMore: page.hasMore,
        loadingMore: false,
      ));
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'reservations',
        'the next page of my reservations did not come',
        error: e,
        stackTrace: st,
      );
      if (!ref.mounted) return;
      // The pages already read stay on screen; the failure is shown beside
      // them with the way to ask for the next page again.
      state = AsyncData(current._with(loadingMore: false, loadMoreFailure: e));
    }
  }
}

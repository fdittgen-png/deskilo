// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2553 -- My reservations: the sources, the limits, the windows, the
// composer across every host and (C3) the row actions, the tab and source
// filter and the pause while the app is hidden. Re-exported by
// reservation_providers.dart, where these providers began.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/bounded_reads.dart';
import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/backend/connected_pool_host_resolver.dart';
import '../../../core/backend/context_client_providers.dart';
import '../../../core/backend/context_clients.dart'
    show ActiveInstallationHostResolver, ResolvedWorkspaceHost;
import '../../../core/lifecycle/app_foreground.dart';
import '../../../core/session/session_source.dart';
import '../../../core/settings/active_settings.dart';
import '../../../core/time/clock.dart';
import '../../../core/trace/trace_logger.dart';
import '../data/host_my_reservation_actions.dart';
import '../data/host_my_reservations_repository.dart';
import '../domain/my_reservations.dart';
import '../domain/my_reservations_composition.dart';
import 'reservation_providers.dart' show myReservationsSourcesProvider;

part 'my_reservations_providers.g.dart';

// #2553 -- a person's own reservations across every workspace host their
// account names. C1 read the selected workspace's host; C2 reads each
// source with its own verified client, at most `personal.read_concurrency`
// hosts at a time, each waited for `personal.read_timeout_seconds`, and
// merges the pages by start time. Each host keeps its own state: one that
// fails or cannot be reached is said beside the others' bookings, with its
// own Try again. A page that arrives after the account changed, or for a
// view that was rebuilt meanwhile, is dropped.

/// The read, one host per call through that host's own verified client;
/// the limits from the personal home's platform settings. Demo overrides
/// it with the fixture's spaces.
@riverpod
MyReservationsRepository myReservationsRepository(Ref ref) =>
    HostMyReservationsRepository(
      platformSettings: () => ref.read(platformSettingsProvider.future),
      hostOf: (source) => _hostOf(ref, source),
    );

/// #2553 C3 -- View, Cancel and Check in of a row, each through the host
/// the row was read from; View reads with the same strict adapter. Demo
/// overrides it with the fixture's spaces.
@riverpod
MyReservationActions myReservationActions(Ref ref) => HostMyReservationActions(
      pages: ref.watch(myReservationsRepositoryProvider),
      hostOf: (source) => _hostOf(ref, source),
    );

/// The verified host of [source]: the installation the app is signed in to,
/// or the connected pool's pinned client for the source's origin.
Future<ResolvedWorkspaceHost> _hostOf(Ref ref, MyReservationsSource source) =>
    resolveMyReservationsHost(
      source,
      connected: () => ref.read(connectedSourcesProvider.future),
      resolverFor: (origin) => ConnectedPoolHostResolver(
        active: ActiveInstallationHostResolver(
          ref.read(personalClientProvider),
          ref.read(installationIdReaderProvider),
        ),
        root: ref.read(personalClientProvider),
        pool: () => ref.read(connectedInstallationsProvider),
        sourceOf: (_) => origin,
      ),
    );

/// The personal home's limits for these reads; a registry without the
/// rows fails typed.
@Riverpod(retry: myReservationsRetry)
Future<MyReservationsLimits> myReservationsLimits(Ref ref) {
  ref.watch(sessionStateProvider.select((s) => s.value));
  return ref.watch(myReservationsRepositoryProvider).limits();
}

/// The window a person starts with and the longest one they may ask for.
@Riverpod(retry: myReservationsRetry)
class MyReservationsWindowController extends _$MyReservationsWindowController {
  @override
  Future<MyReservationsWindow> build() async {
    final now = ref.watch(clockProvider).now();
    final limits = await ref.watch(myReservationsLimitsProvider.future);
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

/// #2553 C3 -- the period of the Past tab: by default the days that end
/// with today, read newest first; changed like the other.
@Riverpod(retry: myReservationsRetry)
class MyPastReservationsWindowController
    extends _$MyPastReservationsWindowController {
  @override
  Future<MyReservationsWindow> build() async {
    final now = ref.watch(clockProvider).now();
    final limits = await ref.watch(myReservationsLimitsProvider.future);
    return MyReservationsWindow.untilToday(
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

/// #2553 C3 -- what My reservations shows: a tab and, optionally, one
/// source (an installation) alone.
@immutable
class MyReservationsFilter {
  const MyReservationsFilter({
    this.tab = MyReservationsTab.upcoming,
    this.source,
  });

  final MyReservationsTab tab;

  /// The installation shown alone; null for every source.
  final String? source;

  @override
  bool operator ==(Object other) =>
      other is MyReservationsFilter && other.tab == tab && other.source == source;

  @override
  int get hashCode => Object.hash(tab, source);
}

/// #2553 C3 -- the tab and source chosen; kept while the view is shown,
/// through a load-more or a retry.
@riverpod
class MyReservationsFilterController extends _$MyReservationsFilterController {
  @override
  MyReservationsFilter build() => const MyReservationsFilter();

  void showTab(MyReservationsTab tab) =>
      state = MyReservationsFilter(tab: tab, source: state.source);

  /// Only [installationId]; every source when null.
  void showSource(String? installationId) =>
      state = MyReservationsFilter(tab: state.tab, source: installationId);
}

/// The composition of one [MyReservationsQuery] (a window): every source's
/// first page read through the bounded reads, each slot emitted as soon as
/// its host answers; [loadMore] and [retry] per host.
@Riverpod(retry: myReservationsRetry)
class MyReservationsComposer extends _$MyReservationsComposer {
  int _generation = 0;
  String? _principal;
  BoundedReads? _reads;
  Duration _timeout = Duration.zero;

  @override
  Future<MyReservationsComposition> build(MyReservationsQuery query) async {
    final generation = ++_generation;
    final principal = ref.watch(sessionStateProvider.select((s) => s.value));
    final limitsAnswer = ref.watch(myReservationsLimitsProvider.future);
    // Both watched before the first await; a failure of the second while
    // the first is awaited must not go unhandled.
    final sourcesAnswer = ref.watch(myReservationsSourcesProvider.future)..ignore();
    final limits = await limitsAnswer;
    final sources = await sourcesAnswer;
    final reads = BoundedReads(limits.concurrency);
    ref.onDispose(reads.close);
    // C3 -- hidden, no read starts; the ones asked meanwhile (one per host:
    // a slot already reading is not asked again) start once on resume.
    if (!ref.read(appForegroundProvider)) reads.pause();
    ref.listen<bool>(
      appForegroundProvider,
      (_, foreground) => foreground ? reads.resume() : reads.pause(),
    );
    _principal = principal;
    _reads = reads;
    _timeout = limits.timeout;
    for (final source in sources) {
      unawaited(_read(generation, source, query, first: true));
    }
    return MyReservationsComposition(
      List.unmodifiable([
        for (final source in sources) MyReservationsSlot.reading(source),
      ]),
      direction: query.direction,
    );
  }

  /// Whether a read started in [generation] may still change the view: the
  /// same build, the same signed-in account.
  bool _current(int generation) =>
      ref.mounted &&
      generation == _generation &&
      ref.read(sessionStateProvider).value == _principal;

  Future<void> _read(
    int generation,
    MyReservationsSource source,
    MyReservationsQuery asked, {
    required bool first,
  }) async {
    final reads = _reads;
    if (reads == null) return;
    final repository = ref.read(myReservationsRepositoryProvider);
    MyReservationsPage? page;
    Object? failure;
    try {
      page = await reads.run(
        () => repository.page(source, asked).timeout(_timeout),
      );
    } on Object catch (e, st) {
      failure = e;
      TraceLogger.instance.warn(
        'reservations',
        'a host of my reservations did not answer',
        error: e,
        stackTrace: st,
      );
    }
    if (!_current(generation)) return;
    // The first slots are emitted by build; a page may come before them.
    // A failed build has nothing to place the answer in.
    try {
      await future;
    } on Object {
      // trace-exempt: the build's own failure is the view's state.
      return;
    }
    if (!_current(generation)) return;
    final composition = state.value;
    if (composition == null) return;
    state = AsyncData(
      composition.answered(source, page: page, failure: failure, first: first),
    );
  }

  /// The next page of every host that has one, or of host [only]; the
  /// pages already read stay on screen while it comes.
  void loadMore({String? only}) {
    final composition = state.value;
    if (composition == null) return;
    final (next, asks) = composition.askingMore(only: only);
    if (asks.isEmpty) return;
    state = AsyncData(next);
    for (final (source, cursor) in asks) {
      unawaited(_read(_generation, source, query.continuedAfter(cursor), first: false));
    }
  }

  /// Reads the first page of the host [installationId] again; the other
  /// hosts' bookings stay as they are.
  void retry(String installationId) {
    final composition = state.value;
    final slot = composition?.slotOf(installationId);
    if (composition == null ||
        slot == null ||
        slot.state != MyReservationsSlotState.failed) {
      return;
    }
    state = AsyncData(
      composition.replacing(MyReservationsSlot.reading(slot.source)),
    );
    unawaited(_read(_generation, slot.source, query, first: true));
  }

  /// C3 -- the row [reservationId] of host [installationId] and that
  /// host's source, captured now: a later workspace switch or rebuild
  /// cannot retarget the action.
  (MyReservationsSource, MyReservationItem) _row(
    String installationId,
    String reservationId,
  ) {
    final slot = state.value?.slotOf(installationId);
    if (slot != null) {
      for (final item in slot.items) {
        if (item.id == reservationId) return (slot.source, item);
      }
    }
    throw MyReservationsRefused(MyReservationsFailure.gone, detail: reservationId);
  }

  /// Places [fresh] (or removes the row, when null) if the view is still
  /// the one the action began in.
  void _place(int generation, String installationId, String id, MyReservationItem? fresh) {
    if (!_current(generation)) return;
    final composition = state.value;
    if (composition == null) return;
    state = AsyncData(composition.withItem(installationId, id, fresh));
  }

  /// C3 -- the row as its own host holds it now, placed in the list; a
  /// row its host no longer lists leaves it, with the typed refusal.
  Future<MyReservationItem> view(String installationId, String reservationId) async {
    final generation = _generation;
    final (source, item) = _row(installationId, reservationId);
    try {
      final fresh = await ref.read(myReservationActionsProvider).view(source, item);
      _place(generation, installationId, reservationId, fresh);
      return fresh;
    } on MyReservationsRefused catch (e, st) {
      if (e.failure == MyReservationsFailure.gone) {
        _place(generation, installationId, reservationId, null);
      }
      Error.throwWithStackTrace(e, st);
    }
  }

  /// C3 -- cancels the row on its own host, then reads it again there.
  Future<void> cancel(String installationId, String reservationId) =>
      _act(installationId, reservationId, (actions, source, item) => actions.cancel(source, item));

  /// C3 -- checks in to the row on its own host, then reads it again there.
  Future<void> checkIn(String installationId, String reservationId) =>
      _act(installationId, reservationId, (actions, source, item) => actions.checkIn(source, item));

  Future<void> _act(
    String installationId,
    String reservationId,
    Future<void> Function(MyReservationActions, MyReservationsSource, MyReservationItem) action,
  ) async {
    final generation = _generation;
    final (source, item) = _row(installationId, reservationId);
    final actions = ref.read(myReservationActionsProvider);
    await action(actions, source, item);
    try {
      _place(generation, installationId, reservationId, await actions.view(source, item));
    } on Object catch (e, st) {
      // The action was done; only its echo failed. The view reads again
      // rather than show the row as it was before.
      TraceLogger.instance.warn(
        'reservations',
        'a changed reservation was not read again',
        error: e,
        stackTrace: st,
      );
      if (_current(generation)) ref.invalidateSelf();
    }
  }
}

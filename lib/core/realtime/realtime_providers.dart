// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../backend/context_client_providers.dart';
import '../trace/trace_logger.dart';
import '../ui/app_durations.dart';
import 'invalidation_map.dart';
import 'invalidation_registry.dart' show InvalidationScope;
import 'realtime_sync.dart';
import 'realtime_wiring.dart';

part 'realtime_providers.g.dart';

@Riverpod(keepAlive: true)
RealtimeSync realtimeSync(Ref ref) =>
    SupabaseRealtimeSync(ref.watch(realtimeWorkspaceClientProvider));

/// #2564 O5 — the account target's feed, on the personal home's client.
@Riverpod(keepAlive: true)
RealtimeSync accountRealtimeSync(Ref ref) =>
    SupabaseRealtimeSync(ref.watch(personalClientProvider));

/// A test or demo scope's feed: both targets read [sync].
List<Override> realtimeSyncOverrides(RealtimeSync sync) => [
  realtimeSyncProvider.overrideWithValue(sync),
  accountRealtimeSyncProvider.overrideWithValue(sync),
];

/// The two targets of #2564: each has its own channel, its own invalidator
/// and only the registry scope that is its own.
enum RealtimeTarget {
  /// The selected workspace's change feed (one channel per workspace).
  workspace({InvalidationScope.workspace}),

  /// The personal home's feed: what spans workspaces.
  account({InvalidationScope.account});

  const RealtimeTarget(this.scopes);

  final Set<InvalidationScope> scopes;
}

/// How long changes are coalesced before invalidating (#413): a burst
/// (a series booking writes dozens of rows) becomes one refetch.
@visibleForTesting
const kRealtimeDebounce = AppDurations.realtimeDebounce;

/// Watches app lifecycle for the invalidator: while the app was
/// backgrounded the realtime socket may have been paused by the OS with
/// no error ever surfacing, so RESUME triggers a full resync (#577).
/// Kiosks that sleep overnight wake up fresh instead of showing
/// yesterday's plan.
class ResumeResyncObserver with WidgetsBindingObserver {
  ResumeResyncObserver(this.onResume);

  final void Function() onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}

/// Subscribes to ONE target's change feed and invalidates
/// exactly the providers of that target's scope that cache each table — so every device,
/// INCLUDING the one that made the change, repaints without restarts or
/// manual refreshes (#413). Watched from the shell and the kiosk, alive
/// with the app. The table → providers map lives in
/// [invalidationFor] (#577) and is shared with the manual mutation path.
@Riverpod(keepAlive: true)
class RealtimeInvalidator extends _$RealtimeInvalidator {
  StreamSubscription<String>? _sub;
  Timer? _batchWindow;
  ResumeResyncObserver? _observer;
  final _pending = <String>{};
  Set<InvalidationScope> _scopes = const {};

  /// #1093 — which build owns the channel. The notifier is keepAlive, so
  /// ONE instance is reused across rebuilds and [_sub] is a single shared
  /// field: two builds overlapping (a workspace switched twice, a resume
  /// arriving mid-switch) would both tear down, both await, and both
  /// assign — leaving the loser's channel open, unreferenced, and still
  /// feeding invalidations for a workspace the member has left.
  int _generation = 0;

  @override
  Future<void> build(RealtimeTarget target) async {
    final generation = ++_generation;
    ref.onDispose(_teardown);
    // #2562 -- the channel's lifetime is the lifetime of the client it runs
    // on: watched before the first await, so a workspace that moves to
    // another installation (even under the same local id), or whose
    // connection ends, rebuilds this channel instead of leaving it on the
    // old client. A refused client (typed failure) leaves no channel.
    final sync = ref.watch(
      target == RealtimeTarget.workspace
          ? realtimeSyncProvider
          : accountRealtimeSyncProvider,
    );
    final workspaceId = await ref.watch(realtimeWorkspaceIdProvider.future);
    // A build superseded while it awaited installs nothing: the build
    // that superseded it owns the channel and will tear this one's
    // predecessor down itself.
    if (generation != _generation) return;
    // Tear down AFTER the await, not before: the old channel stays live
    // while the new workspace is being read, so there is no window in
    // which changes are missed.
    _teardown();
    if (workspaceId == null) return;
    _observer = ResumeResyncObserver(() {
      _pending.add(kResyncSignal);
      _batchWindow ??= Timer(kRealtimeDebounce, _flush);
    });
    WidgetsBinding.instance.addObserver(_observer!);
    final feed = switch (target) {
      RealtimeTarget.workspace => sync.watch(workspaceId),
      RealtimeTarget.account => sync.watchAccount(),
    };
    _scopes = target.scopes;
    _sub = feed.listen((table) {
      _pending.add(table);
      _batchWindow ??= Timer(kRealtimeDebounce, _flush);
    });
  }

  /// Releases everything a previous build installed. Idempotent — the
  /// dispose callback and the next build both call it.
  void _teardown() {
    unawaited(_sub?.cancel());
    _sub = null;
    _batchWindow?.cancel();
    _batchWindow = null;
    // #2019 — signals collected for the old channel never flush into the
    // next workspace's batch.
    _pending.clear();
    final observer = _observer;
    if (observer != null) {
      WidgetsBinding.instance.removeObserver(observer);
      _observer = null;
    }
  }

  void _flush() {
    _batchWindow = null;
    final tables = Set.of(_pending);
    _pending.clear();
    if (!ref.mounted) return;
    // A resync subsumes every per-table signal in the batch.
    final lookup = ref.read(invalidationLookupProvider);
    final scopes = _scopes;
    TableInvalidation lookupHere(String table) => lookup(table, scopes: scopes);
    final entries = tables.contains(kResyncSignal)
        ? mappedTables.map(lookupHere)
        : tables.map(lookupHere);
    unawaited(_applyAll(entries.toList(growable: false), _generation));
  }

  /// #2019 — batches that actually invalidated (tests).
  @visibleForTesting
  int appliedBatches = 0;

  /// #1084 — the disk cache is busted ONCE and, crucially, BEFORE the
  /// providers are invalidated. Firing the bust unawaited and
  /// invalidating synchronously let the refetch win the race and land
  /// back on the entry that was about to be deleted.
  ///
  /// #2019 — the batch belongs to the build [generation] it was collected
  /// under: after the awaited bust, a batch whose build was superseded (a
  /// workspace, account or installation switch) invalidates nothing. And
  /// each provider is invalidated once, however many tables named it.
  Future<void> _applyAll(
    List<TableInvalidation> entries,
    int generation,
  ) async {
    if (entries.any((e) => e.bustsPlanCache)) {
      try {
        await ref.read(planCacheBusterProvider)();
      } on Object catch (e, st) {
        // A cache that refuses to clear must not stop the repaint — the
        // refetch may still be network-true.
        TraceLogger.instance.warn(
          'realtime',
          'plan cache bust failed before invalidation',
          error: e,
          stackTrace: st,
        );
      }
    }
    if (!ref.mounted || generation != _generation) return;
    final providers = {
      for (final entry in entries) ...entry.providers,
    };
    for (final provider in providers) {
      ref.invalidate(provider);
    }
    appliedBatches++;
  }
}

// SPDX-License-Identifier: 0BSD
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../features/plan/providers/floor_plan_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import 'invalidation_map.dart';
import 'realtime_sync.dart';

part 'realtime_providers.g.dart';

@Riverpod(keepAlive: true)
RealtimeSync realtimeSync(Ref ref) =>
    SupabaseRealtimeSync(Supabase.instance.client);

/// How long changes are coalesced before invalidating (#413): a burst
/// (a series booking writes dozens of rows) becomes one refetch.
const kRealtimeDebounce = Duration(milliseconds: 300);

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

/// Subscribes to the active workspace's change feed and invalidates
/// exactly the providers that cache each table — so every device,
/// INCLUDING the one that made the change, repaints without restarts or
/// manual refreshes (#413). Watched from the shell and the kiosk, alive
/// with the app. The table → providers map lives in
/// [invalidationFor] (#577) and is shared with the manual mutation path.
@Riverpod(keepAlive: true)
class RealtimeInvalidator extends _$RealtimeInvalidator {
  StreamSubscription<String>? _sub;
  Timer? _debounce;
  ResumeResyncObserver? _observer;
  final _pending = <String>{};

  /// #1093 — which build owns the channel. The notifier is keepAlive, so
  /// ONE instance is reused across rebuilds and [_sub] is a single shared
  /// field: two builds overlapping (a workspace switched twice, a resume
  /// arriving mid-switch) would both tear down, both await, and both
  /// assign — leaving the loser's channel open, unreferenced, and still
  /// feeding invalidations for a workspace the member has left.
  int _generation = 0;

  @override
  Future<void> build() async {
    final generation = ++_generation;
    ref.onDispose(_teardown);
    final workspace = await ref.watch(currentWorkspaceProvider.future);
    // A build superseded while it awaited installs nothing: the build
    // that superseded it owns the channel and will tear this one's
    // predecessor down itself.
    if (generation != _generation) return;
    // Tear down AFTER the await, not before: the old channel stays live
    // while the new workspace is being read, so there is no window in
    // which changes are missed.
    _teardown();
    if (workspace == null) return;
    _observer = ResumeResyncObserver(() {
      _pending.add(kResyncSignal);
      _debounce ??= Timer(kRealtimeDebounce, _flush);
    });
    WidgetsBinding.instance.addObserver(_observer!);
    _sub = ref
        .read(realtimeSyncProvider)
        .watch(workspace.id)
        .listen((table) {
      _pending.add(table);
      _debounce ??= Timer(kRealtimeDebounce, _flush);
    });
  }

  /// Releases everything a previous build installed. Idempotent — the
  /// dispose callback and the next build both call it.
  void _teardown() {
    _sub?.cancel();
    _sub = null;
    _debounce?.cancel();
    _debounce = null;
    final observer = _observer;
    if (observer != null) {
      WidgetsBinding.instance.removeObserver(observer);
      _observer = null;
    }
  }

  void _flush() {
    _debounce = null;
    final tables = Set.of(_pending);
    _pending.clear();
    if (!ref.mounted) return;
    // A resync subsumes every per-table signal in the batch.
    if (tables.contains(kResyncSignal)) {
      for (final table in mappedTables) {
        _apply(invalidationFor(table));
      }
      return;
    }
    for (final table in tables) {
      _apply(invalidationFor(table));
    }
  }

  void _apply(TableInvalidation entry) {
    if (entry.bustsPlanCache) {
      unawaited(ref.read(floorPlanRepositoryProvider).invalidateCache());
    }
    for (final provider in entry.providers) {
      ref.invalidate(provider);
    }
  }
}

// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../workspace/providers/workspace_providers.dart';
import '../domain/default_booking_period.dart';

part 'default_period_controller.g.dart';

/// Persists each member's default reservation period per workspace
/// (#586). Same seam shape as `DefaultLevelStore` so widget tests never
/// touch platform channels.
abstract class DefaultPeriodStore {
  /// The stored period wire for [workspaceId], or null when never chosen.
  Future<String?> read(String workspaceId);

  /// Persists [wire] as the default for [workspaceId]; null clears it.
  Future<void> write(String workspaceId, String? wire);
}

class PrefsDefaultPeriodStore implements DefaultPeriodStore {
  static String _key(String workspaceId) => 'default_period_$workspaceId';

  @override
  Future<String?> read(String workspaceId) async =>
      (await SharedPreferences.getInstance()).getString(_key(workspaceId));

  @override
  Future<void> write(String workspaceId, String? wire) async {
    final prefs = await SharedPreferences.getInstance();
    if (wire == null) {
      await prefs.remove(_key(workspaceId));
    } else {
      await prefs.setString(_key(workspaceId), wire);
    }
  }
}

/// Test double.
class InMemoryDefaultPeriodStore implements DefaultPeriodStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String workspaceId) async => values[workspaceId];

  @override
  Future<void> write(String workspaceId, String? wire) async {
    if (wire == null) {
      values.remove(workspaceId);
    } else {
      values[workspaceId] = wire;
    }
  }
}

@Riverpod(keepAlive: true)
DefaultPeriodStore defaultPeriodStore(Ref ref) =>
    PrefsDefaultPeriodStore();

/// The active workspace's stored default period, validated against what
/// the CURRENT booking configuration still offers — a preference saved
/// under half-days is silently ignored after the owner reconfigures to
/// a minute grid.
@Riverpod(keepAlive: true)
class DefaultPeriod extends _$DefaultPeriod {
  @override
  Future<DefaultBookingPeriod?> build() async {
    final workspace = await ref.watch(currentWorkspaceProvider.future);
    if (workspace == null) return null;
    final granularity =
        await ref.watch(bookingGranularityProvider.future);
    final stored = DefaultBookingPeriod.fromWire(
      await ref.watch(defaultPeriodStoreProvider).read(workspace.id),
    );
    if (stored == null) return null;
    return defaultPeriodChoicesFor(granularity).contains(stored)
        ? stored
        : null;
  }

  Future<void> select(DefaultBookingPeriod? period) async {
    state = AsyncData(period);
    final workspace = await ref.read(currentWorkspaceProvider.future);
    if (workspace == null) return;
    await ref
        .read(defaultPeriodStoreProvider)
        .write(workspace.id, period?.wire);
  }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3603 — the desk's navigation choice on this device: the sidebar with
// labels, or narrowed to the rail of icons. Only a large window offers the
// choice (an expanded one always shows the rail); it is kept per device,
// like the bar swiped away (#1173), through the same flag store.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/trace/trace_logger.dart';
import 'shell_bar_visibility.dart';

part 'desk_navigation.g.dart';

@Riverpod(keepAlive: true)
ShellFlagStore deskRailCollapsedStore(Ref ref) =>
    const PrefsShellFlagStore('desk_rail_collapsed');

/// Whether the person narrowed the desk's sidebar to the rail. Loading
/// reads as the sidebar: the view that names every destination.
@Riverpod(keepAlive: true)
class DeskRailCollapsed extends _$DeskRailCollapsed {
  @override
  Future<bool> build() => ref.watch(deskRailCollapsedStoreProvider).read();

  /// Narrow or widen the sidebar, remembering the choice on this device.
  Future<void> set({required bool collapsed}) async {
    if (state.value == collapsed) return;
    state = AsyncData(collapsed);
    try {
      await ref.read(deskRailCollapsedStoreProvider).write(value: collapsed);
    } on Object catch (e, st) {
      // The menu still changed; only the memory of it is lost.
      TraceLogger.instance.warn(
        'shell',
        'desk navigation choice not persisted',
        error: e,
        stackTrace: st,
      );
    }
  }
}

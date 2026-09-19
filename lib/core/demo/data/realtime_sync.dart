// SPDX-License-Identifier: 0BSD
import 'dart:async';

import 'package:deskilo/core/realtime/realtime_sync.dart';

/// Test seam for push-driven freshness (#413): tests call [emit] to
/// simulate a DB change event; the default instance in the standard
/// overrides simply never emits.
class FakeRealtimeSync implements RealtimeSync {
  final _controller = StreamController<String>.broadcast();

  /// Workspace ids watch() was called with — pins the subscription.
  final watched = <String>[];

  @override
  Stream<String> watch(String workspaceId) {
    watched.add(workspaceId);
    return _controller.stream;
  }

  void emit(String table) => _controller.add(table);
}

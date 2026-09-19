// SPDX-License-Identifier: 0BSD
//
// #1379 — whether the app is showing the demonstration space.
//
// One boolean, in the root container, read by the composition root. It is
// deliberately NOT persisted: ADR 0030 settles that a demo session lasts
// as long as the app is open, so a restart lands in the real app rather
// than dropping somebody back into a synthetic workspace they may have
// forgotten they were in.
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'demo_entry.g.dart';

@Riverpod(keepAlive: true)
class DemoEntry extends _$DemoEntry {
  @override
  bool build() => false;

  /// Enters the demonstration space.
  void enter() => state = true;

  /// Returns to the real app.
  ///
  /// The caller invalidates the session alongside this, so entering again
  /// is a fresh, canonical demo rather than whatever the last visitor
  /// left behind — the same promise a restart makes.
  void leave() => state = false;
}

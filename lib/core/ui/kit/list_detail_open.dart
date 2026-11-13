// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3860 — whether a record stands open beside the list. The scaffold
// (list_detail_scaffold.dart) is the one that knows: it says so to what it
// holds, so a records table answers by its priorities without comparing a
// width of its own.
import 'package:flutter/widgets.dart';

/// Tells the list under it that a record is open beside it.
class ListDetailOpen extends InheritedWidget {
  const ListDetailOpen({required this.open, required super.child, super.key});

  /// Whether a record stands beside the list, taking part of its width.
  /// False for the list alone and for a pane standing over the list's end.
  final bool open;

  /// Whether the list at [context] has a record open beside it.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ListDetailOpen>()?.open ??
      false;

  @override
  bool updateShouldNotify(ListDetailOpen old) => open != old.open;
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3619 — the row the arrows stand on stays in view. A row has a minimum
// height, not a fixed one (a name on two lines, a larger text scale), so a
// built row is revealed by its own context. A row not built yet (past the
// lazily built ones) is first estimated at the minimum height, then looked
// for again after each frame, one viewport further in the direction of
// travel, a few frames at most.
import 'dart:async';

import 'package:flutter/widgets.dart';

/// The rows of one table, by key, and the reveal of the one focused.
class RowReveal {
  RowReveal(this._scroll, this._mounted);

  final ScrollController _scroll;

  /// Whether the table is still there.
  final bool Function() _mounted;
  final _keys = <String, GlobalKey>{};

  /// How many frames a jump looks for its row before giving up.
  static const int _tries = 6;

  /// The key the row of [rowKey] is built under.
  GlobalKey keyOf(String rowKey) => _keys.putIfAbsent(rowKey, GlobalKey.new);

  /// Brings the row of [rowKey], at [index], into view; [down] is the
  /// direction of travel.
  void reveal(
    String rowKey,
    int index,
    double rowHeight, {
    required bool down,
  }) {
    if (!_scroll.hasClients) return;
    if (_revealBuilt(rowKey, down: down)) return;
    final p = _scroll.position;
    final extent = rowHeight + 1; // content-fit: a row and its divider
    _scroll.jumpTo(
      (index * extent).clamp(p.minScrollExtent, p.maxScrollExtent),
    );
    _afterFrame(rowKey, down: down, tries: _tries);
  }

  /// Brings the built row of [rowKey] into view; false while not built.
  bool _revealBuilt(String rowKey, {required bool down}) {
    final target = _keys[rowKey]?.currentContext;
    if (target == null || !target.mounted) return false;
    unawaited(
      Scrollable.ensureVisible(
        target,
        alignmentPolicy: down
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      ),
    );
    return true;
  }

  void _afterFrame(String rowKey, {required bool down, required int tries}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_mounted() || !_scroll.hasClients) return;
      if (_revealBuilt(rowKey, down: down) || tries <= 0) return;
      final p = _scroll.position;
      final step = down ? p.viewportDimension : -p.viewportDimension;
      _scroll.jumpTo(
        (p.pixels + step).clamp(p.minScrollExtent, p.maxScrollExtent),
      );
      _afterFrame(rowKey, down: down, tries: tries - 1);
    });
  }
}

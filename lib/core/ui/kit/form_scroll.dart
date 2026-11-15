// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3946 — a form's page: its controls in ONE scrolling column, all built,
// walked by Tab in the order they are built.
//
// Built: a lazily built list (ListView with children) drops the controls
// that left the screen and builds new ones when they return, so a person
// who tabs round a long form meets its first control again as a different
// stop. A form holds a dozen rows, not thousands: it builds them all. Rows
// of data (a records table, a feed) stay lazy lists.
//
// Walked in that order: the reading order sorts the stops by their place on
// screen, and rows of unequal height (a field beside a taller one) come
// round twice as the column scrolls under Tab. [PageTraversalPolicy], the
// policy of the page area on the desk and off it (#4034), keeps the
// column's controls in tree order.
// (A group of its own inside the page would take the page out of the desk's
// order: Tab would never leave it.)
import 'package:flutter/material.dart';

/// [children] stacked in one scrolling column, as a form page's body.
class FormScroll extends StatelessWidget {
  const FormScroll({
    required this.children,
    this.padding = EdgeInsets.zero,
    this.controller,
    super.key,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  /// The scroll controller, when the page drives its scrolling.
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => _InFormScroll(
    child: SingleChildScrollView(
      controller: controller,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

/// Marks what is inside a [FormScroll].
class _InFormScroll extends InheritedWidget {
  const _InFormScroll({required super.child});

  @override
  bool updateShouldNotify(_InFormScroll oldWidget) => false;
}

/// The reading order, except that what scrolls is walked as one block where
/// its viewport stands: the controls of a vertically scrolling page come
/// after the bar above it (a page's own bar) and before what is under it (a
/// bottom bar with Save), wherever the scrolling has carried them. #4034 —
/// without it a control scrolled above the viewport is read as standing
/// above the bar, and Tab, coming round, enters the page in its middle.
/// The controls of a [FormScroll] are walked in the order they are built;
/// those of any other scrolling page in the reading order among themselves.
class PageTraversalPolicy extends ReadingOrderTraversalPolicy {
  PageTraversalPolicy({super.requestFocusCallback});

  static bool _inForm(FocusNode node) =>
      node.context?.getInheritedWidgetOfExactType<_InFormScroll>() != null;

  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants,
    FocusNode currentNode,
  ) {
    final built = descendants.toList();
    final blocks = <ScrollableState, List<FocusNode>>{};
    final tops = <ScrollableState, double>{};
    final standing = <FocusNode>[];
    for (final n in built) {
      final (scroll, top) = _pageScroll(n);
      if (scroll == null || top == null) {
        standing.add(n);
        continue;
      }
      blocks.putIfAbsent(scroll, () => []).add(n);
      tops[scroll] = top;
    }
    if (blocks.isEmpty) return super.sortDescendants(built, currentNode);
    // Each sorted apart: a control scrolled under the bar shares no band
    // with the bar's own. A form's controls in the order they are built.
    for (final MapEntry(key: scroll, value: block) in blocks.entries) {
      if (!block.every(_inForm)) {
        blocks[scroll] = super.sortDescendants(block, currentNode).toList();
      }
    }
    final outside = standing.isEmpty
        ? const <FocusNode>[]
        : super.sortDescendants(standing, currentNode);
    final order = blocks.keys.toList()
      ..sort((a, b) => tops[a]!.compareTo(tops[b]!));
    final out = <FocusNode>[];
    var next = 0;
    for (final n in outside) {
      while (next < order.length && tops[order[next]]! <= n.rect.center.dy) {
        out.addAll(blocks[order[next++]]!);
      }
      out.add(n);
    }
    for (; next < order.length; next++) {
      out.addAll(blocks[order[next]]!);
    }
    return out;
  }

  /// The outermost vertical scrolling area that holds [node] and the top of
  /// its viewport on screen; none when [node] does not scroll vertically.
  static (ScrollableState?, double?) _pageScroll(FocusNode node) {
    final context = node.context;
    if (context == null || !context.mounted) return (null, null);
    ScrollableState? outer;
    var at = Scrollable.maybeOf(context);
    while (at != null) {
      if (at.position.axis == Axis.vertical) outer = at;
      at = Scrollable.maybeOf(at.context);
    }
    final box = outer?.context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) {
      return (null, null);
    }
    return (outer, box.localToGlobal(Offset.zero).dy);
  }
}

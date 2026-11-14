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
// policy of the desk's page area, keeps the column's controls in tree order.
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

/// The reading order, except that the controls of a [FormScroll] are walked
/// in the order they are built, as one block: what the reading order puts
/// above the column's viewport (a page's own bar) comes before it, all else
/// (a bottom bar with Save) after it.
class PageTraversalPolicy extends ReadingOrderTraversalPolicy {
  PageTraversalPolicy({super.requestFocusCallback});

  static bool _inForm(FocusNode node) =>
      node.context?.getInheritedWidgetOfExactType<_InFormScroll>() != null;

  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants,
    FocusNode currentNode,
  ) {
    final inForm = [
      for (final n in descendants)
        if (_inForm(n)) n,
    ];
    final sorted = super.sortDescendants(descendants, currentNode);
    final viewport = inForm.isEmpty ? null : _viewportTop(inForm.first);
    if (viewport == null) return sorted;
    final others = [
      for (final n in sorted)
        if (!_inForm(n)) n,
    ];
    return [
      for (final n in others)
        if (n.rect.center.dy < viewport) n,
      ...inForm,
      for (final n in others)
        if (n.rect.center.dy >= viewport) n,
    ];
  }

  /// The top of the scrolling viewport that holds [node], on screen.
  static double? _viewportTop(FocusNode node) {
    final context = node.context;
    if (context == null || !context.mounted) return null;
    final scrollable = Scrollable.maybeOf(context);
    final box = scrollable?.context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero).dy;
  }
}

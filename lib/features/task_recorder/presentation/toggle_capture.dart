// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The on/off controls the generic recorder layer cannot see as taps: a
// switch, a checkbox, a choice or filter chip. While a recording captures
// values their tap is noted, with the state it left them in (step_values.dart).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../domain/step_values.dart';

bool _isToggle(Widget w) =>
    w is Switch ||
    w is SwitchListTile ||
    w is Checkbox ||
    w is CheckboxListTile ||
    w is FilterChip ||
    w is ChoiceChip;

/// The on/off control under the pointer, found from the render objects it
/// hit: the shallowest toggle above any of them.
Element? toggleElementAt(HitTestResult result) {
  final hit = <RenderObject, int>{};
  var depth = 0;
  for (final entry in result.path) {
    final target = entry.target;
    if (target is RenderObject) hit.putIfAbsent(target, () => depth++);
  }
  Element? best;
  var bestDepth = 1 << 30;
  _visit(WidgetsBinding.instance.rootElement, (e) {
    if (e is! RenderObjectElement) return;
    final at = hit[e.renderObject];
    if (at == null || at >= bestDepth) return;
    var steps = 0;
    Element? found;
    e.visitAncestorElements((parent) {
      if (_isToggle(parent.widget)) {
        found = parent;
        return false;
      }
      return ++steps < 14;
    });
    if (found != null) {
      best = found;
      bestDepth = at;
    }
  });
  return best;
}

/// The state of the toggle at [from] (or the one wrapping it), or null when
/// it is not one.
FlagValue? toggleStateOf(Element from) {
  FlagValue? read(Widget w) => switch (w) {
        Switch(:final value) => FlagValue(value),
        SwitchListTile(:final value) => FlagValue(value),
        Checkbox(:final value?) => FlagValue(value),
        CheckboxListTile(:final value?) => FlagValue(value),
        FilterChip(:final selected) => FlagValue(selected),
        ChoiceChip(:final selected) => FlagValue(selected),
        _ => null,
      };
  FlagValue? found = read(from.widget);
  var steps = 0;
  from.visitAncestorElements((e) {
    found ??= read(e.widget);
    return found == null && ++steps < 8;
  });
  if (found != null) return found;
  var seen = 0;
  _visit(from, (e) {
    found ??= read(e.widget);
  }, stop: () => found != null || ++seen > 120);
  return found;
}

/// Visits the tree below [root] in document order without recursion.
void _visit(
  Element? root,
  void Function(Element e) visit, {
  bool Function()? stop,
}) {
  if (root == null) return;
  final stack = <Element>[root];
  while (stack.isNotEmpty) {
    final e = stack.removeLast();
    visit(e);
    if (stop != null && stop()) return;
    final children = <Element>[];
    e.visitChildElements(children.add);
    stack.addAll(children.reversed);
  }
}

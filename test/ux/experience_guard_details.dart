// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4113 -- what an unnamed control is, so the next finding names it: the
// widgets under its centre, innermost first, and where it is on screen.
part of 'experience_guards.dart';

String _describeAt(WidgetTester tester, Rect rect) {
  final hit = HitTestResult();
  tester.binding.hitTestInView(hit, rect.center, tester.view.viewId);
  final types = <String>[];
  for (final entry in hit.path) {
    final creator = entry.target is RenderObject
        ? (entry.target as RenderObject).debugCreator
        : null;
    if (creator is DebugCreator) {
      types.add(creator.element.widget.runtimeType.toString());
    }
    if (types.length == 3) break;
  }
  final place =
      '${rect.width.toStringAsFixed(0)} x '
      '${rect.height.toStringAsFixed(0)} at '
      '(${rect.left.toStringAsFixed(0)}, ${rect.top.toStringAsFixed(0)})';
  return '${types.isEmpty ? 'no widget under it' : types.join(' < ')}, $place';
}

/// The problem name of an unnamed control at [rect]; hands [note] what the
/// control is (widget types and position) for the finding's message.
String unnamedControl(
  WidgetTester tester,
  Rect rect,
  void Function(String) note,
) {
  note('unnamed control: ${_describeAt(tester, rect)}');
  return 'unnamed control';
}

/// What each unnamed tappable control on screen is.
List<String> unnamedControlDetails(WidgetTester tester) => [
  for (final node in tappableRects(tester))
    if (!node.named) 'unnamed control: ${_describeAt(tester, node.rect)}',
];

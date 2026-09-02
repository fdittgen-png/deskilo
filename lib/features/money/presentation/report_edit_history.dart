// SPDX-License-Identifier: 0BSD
import '../domain/invoice_pdf_template.dart';

/// #822 — undo / redo over ONE document's bands: a linear history of
/// band snapshots. Typing coalesces — edits within [coalesce] of the
/// previous push replace it rather than pile up, so Undo steps back a
/// thought, not a keystroke — while a structural change (a preset, a
/// reset, a move) is always its own step.
class ReportEditHistory {
  ReportEditHistory(ReportBands initial) : _stack = [initial];

  /// How close two pushes must be to count as one step.
  static const Duration coalesce = Duration(milliseconds: 800);

  final List<ReportBands> _stack;
  int _index = 0;
  DateTime? _lastPush;

  ReportBands get current => _stack[_index];
  bool get canUndo => _index > 0;
  bool get canRedo => _index < _stack.length - 1;
  int get length => _stack.length;

  /// Records [bands] as the newest state. A redo tail is dropped. With
  /// [step] false and a push [coalesce]-close to the last one, the last
  /// snapshot is replaced instead — typing. Unchanged bands push nothing.
  void push(ReportBands bands, {required DateTime at, bool step = false}) {
    if (_same(bands, current)) return;
    _stack.removeRange(_index + 1, _stack.length);
    final last = _lastPush;
    final merge = !step &&
        last != null &&
        at.difference(last) < coalesce &&
        _index > 0;
    if (merge) {
      _stack[_index] = bands;
    } else {
      _stack.add(bands);
      _index = _stack.length - 1;
    }
    _lastPush = step ? null : at;
  }

  ReportBands undo() {
    if (canUndo) _index--;
    _lastPush = null;
    return current;
  }

  ReportBands redo() {
    if (canRedo) _index++;
    _lastPush = null;
    return current;
  }

  static bool _same(ReportBands a, ReportBands b) =>
      a.header == b.header && a.body == b.body && a.footer == b.footer;
}

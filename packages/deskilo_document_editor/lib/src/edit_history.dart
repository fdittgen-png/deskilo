// SPDX-License-Identifier: AGPL-3.0-or-later

/// Undo / redo over ONE document: a linear history of snapshots. Typing
/// coalesces - snapshots pushed within [coalesce] of the previous one
/// replace it rather than pile up, so Undo steps back a thought, not a
/// keystroke - while a structural change (`step: true`) is always its own
/// step.
class EditHistory<T> {
  /// [same] says when two snapshots are the same state (default `==`).
  EditHistory(T initial, {bool Function(T a, T b)? same})
    : _stack = [initial],
      _same = same ?? ((a, b) => a == b);

  /// How close two pushes must be to count as one step.
  static const Duration coalesce = Duration(milliseconds: 800);

  final List<T> _stack;
  final bool Function(T a, T b) _same;
  int _index = 0;
  DateTime? _lastPush;

  T get current => _stack[_index];
  bool get canUndo => _index > 0;
  bool get canRedo => _index < _stack.length - 1;
  int get length => _stack.length;

  /// Records [snapshot] as the newest state. A redo tail is dropped. With
  /// [step] false and a push [coalesce]-close to the last one, the last
  /// snapshot is replaced instead. An unchanged snapshot pushes nothing.
  void push(T snapshot, {required DateTime at, bool step = false}) {
    if (_same(snapshot, current)) return;
    _stack.removeRange(_index + 1, _stack.length);
    final last = _lastPush;
    final merge =
        !step && last != null && at.difference(last) < coalesce && _index > 0;
    if (merge) {
      _stack[_index] = snapshot;
    } else {
      _stack.add(snapshot);
      _index = _stack.length - 1;
    }
    _lastPush = step ? null : at;
  }

  T undo() {
    if (canUndo) _index--;
    _lastPush = null;
    return current;
  }

  T redo() {
    if (canRedo) _index++;
    _lastPush = null;
    return current;
  }
}

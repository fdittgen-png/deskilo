// SPDX-License-Identifier: AGPL-3.0-or-later

/// An ordered list of elements and the one that is selected, changed only
/// by returning a new value. The selection follows the element a change
/// moves, so a move never leaves the pointer on a neighbour.
final class ElementEdit<T> {
  /// [items] are copied; [selected] must be null or an index into them.
  ElementEdit(Iterable<T> items, {this.selected})
    : items = List<T>.unmodifiable(items) {
    final at = selected;
    if (at != null && (at < 0 || at >= this.items.length)) {
      throw RangeError.range(at, 0, this.items.length - 1, 'selected');
    }
  }

  final List<T> items;

  /// The index of the selected element, or null when none is.
  final int? selected;

  /// The same elements with [index] selected (null clears the selection).
  ElementEdit<T> select(int? index) => ElementEdit(items, selected: index);

  /// Inserts [element] after the selected one - at the end when nothing
  /// is selected - and selects it.
  ElementEdit<T> insertAfterSelection(T element) {
    final at = selected;
    return insertBelow(at ?? items.length - 1, element);
  }

  /// Inserts [element] directly below [index] and selects it.
  ElementEdit<T> insertBelow(int index, T element) {
    final list = List<T>.of(items);
    final at = (index + 1).clamp(0, list.length);
    list.insert(at, element);
    return ElementEdit(list, selected: at);
  }

  /// Removes the element at [index]; nothing stays selected.
  ElementEdit<T> remove(int index) {
    if (index < 0 || index >= items.length) return this;
    final list = List<T>.of(items)..removeAt(index);
    return ElementEdit(list);
  }

  /// Moves the element at [index] by [delta] places and selects it where
  /// it lands. Out of range changes nothing.
  ElementEdit<T> moveBy(int index, int delta) {
    final to = index + delta;
    if (index < 0 || index >= items.length) return this;
    if (to < 0 || to >= items.length) return this;
    final list = List<T>.of(items);
    final element = list.removeAt(index);
    list.insert(to, element);
    return ElementEdit(list, selected: to);
  }

  /// A drag: the element at [from] lands BEFORE the element at [before]
  /// (the drop target) and is selected where it lands.
  ElementEdit<T> moveBefore(int from, int before) {
    if (from == before) return this;
    if (from < 0 || from >= items.length) return this;
    if (before < 0 || before > items.length) return this;
    final list = List<T>.of(items);
    final element = list.removeAt(from);
    final to = before > from ? before - 1 : before;
    list.insert(to, element);
    return ElementEdit(list, selected: to);
  }
}

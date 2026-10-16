// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2592 C2 - the editing primitives used by a host that is not Deskilo: an
// inspection checklist edited as an ordered list, with a selection, a
// reorder, a field token and an undo history.
import 'package:deskilo_document_editor/deskilo_document_editor.dart';
import 'package:test/test.dart';

void main() {
  group('ElementEdit', () {
    final base = ElementEdit(['a', 'b', 'c']);

    test('insertAfterSelection goes after the selection, else at the end', () {
      final none = base.insertAfterSelection('x');
      expect(none.items, ['a', 'b', 'c', 'x']);
      expect(none.selected, 3);

      final after = base.select(0).insertAfterSelection('x');
      expect(after.items, ['a', 'x', 'b', 'c']);
      expect(after.selected, 1);

      expect(ElementEdit<String>([]).insertAfterSelection('x').items, ['x']);
    });

    test('insertBelow selects the new element', () {
      final next = base.insertBelow(1, 'x');
      expect(next.items, ['a', 'b', 'x', 'c']);
      expect(next.selected, 2);
    });

    test('moveBy moves and selects; out of range changes nothing', () {
      final up = base.moveBy(2, -1);
      expect(up.items, ['a', 'c', 'b']);
      expect(up.selected, 1);
      expect(identical(base.moveBy(0, -1), base), isTrue);
      expect(identical(base.moveBy(2, 1), base), isTrue);
    });

    test('moveBefore is a drop on a target', () {
      expect(base.moveBefore(0, 3).items, ['b', 'c', 'a']);
      expect(base.moveBefore(0, 3).selected, 2);
      expect(base.moveBefore(2, 0).items, ['c', 'a', 'b']);
      expect(base.moveBefore(2, 0).selected, 0);
      expect(identical(base.moveBefore(1, 1), base), isTrue);
    });

    test('remove clears the selection; the original is untouched', () {
      final next = base.select(1).remove(1);
      expect(next.items, ['a', 'c']);
      expect(next.selected, isNull);
      expect(base.items, ['a', 'b', 'c']);
    });

    test('the list cannot be mutated through the value', () {
      expect(() => base.items.add('x'), throwsUnsupportedError);
      expect(() => base.select(5), throwsRangeError);
    });
  });

  group('insertTokenAt', () {
    test('splices at the caret and puts the caret after the token', () {
      final r = insertTokenAt('Hello !', '{{ name }}', caret: 6);
      expect(r.text, 'Hello {{ name }}!');
      expect(r.caret, 16);
    });

    test('appends without a caret or with one outside the text', () {
      expect(insertTokenAt('ab', 'X').text, 'abX');
      expect(insertTokenAt('ab', 'X', caret: -1).text, 'abX');
      expect(insertTokenAt('ab', 'X', caret: 9).text, 'abX');
    });
  });

  group('EditHistory', () {
    final t0 = DateTime.utc(2026, 10, 16, 12);

    test('a structural step is its own entry and undo / redo walk it', () {
      final history = EditHistory<String>('one');
      history.push('two', at: t0, step: true);
      history.push('three', at: t0, step: true);
      expect(history.undo(), 'two');
      expect(history.canRedo, isTrue);
      expect(history.redo(), 'three');
      expect(history.canRedo, isFalse);
    });

    test('typing within the window replaces the last snapshot', () {
      final history = EditHistory<String>('');
      history.push('a', at: t0, step: true);
      // The first keystroke after a step opens an entry ...
      history.push('ab', at: t0.add(const Duration(milliseconds: 100)));
      // ... and the ones close behind it replace that entry.
      history.push('abc', at: t0.add(const Duration(milliseconds: 200)));
      expect(history.length, 3);
      expect(history.undo(), 'a');
    });

    test(
      'an unchanged snapshot pushes nothing; a push drops the redo tail',
      () {
        final history = EditHistory<String>('x');
        history.push('x', at: t0);
        expect(history.length, 1);
        history.push('y', at: t0, step: true);
        history.undo();
        history.push('z', at: t0, step: true);
        expect(history.canRedo, isFalse);
        expect(history.current, 'z');
      },
    );

    test('same decides what counts as unchanged', () {
      final history = EditHistory<List<int>>([
        1,
      ], same: (a, b) => a.length == b.length);
      history.push([2], at: t0);
      expect(history.length, 1);
    });
  });
}

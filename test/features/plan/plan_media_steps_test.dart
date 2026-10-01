// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2012 — a plan image write keeps the committed plan usable when Storage
// or the database fails half-way. Replace: upload a NEW object, move the
// reference, then retire the old one; an upload or reference failure
// leaves the old image referenced and intact, and a failed reference
// update never deletes the candidate (it may have committed). Clear: the
// reference first, then the object. An object that cannot be removed is a
// leftover for cleanup, not a failed operation.
import 'package:deskilo/features/plan/data/plan_media_steps.dart';
import 'package:flutter_test/flutter_test.dart';

class _World {
  String? reference = 'ws/l1.old';
  final objects = <String>{'ws/l1.old'};
  final log = <String>[];
  final leftovers = <String>[];
  String? failAt;

  PlanMediaSteps get steps => PlanMediaSteps(
    upload: (p) async {
      log.add('upload $p');
      if (failAt == 'upload') throw StateError('storage down');
      objects.add(p);
    },
    publish: (p) async {
      log.add('publish $p');
      if (failAt == 'publish') throw StateError('db down');
      reference = p;
    },
    remove: (p) async {
      log.add('remove $p');
      if (failAt == 'remove') throw StateError('storage down');
      objects.remove(p);
    },
    onLeftover: (p, _) => leftovers.add(p),
  );

  /// The one state that must never exist: a reference to a missing object.
  bool get dangling => reference != null && !objects.contains(reference);
}

void main() {
  test('replace: upload, publish, then retire the old object', () async {
    final w = _World();
    await w.steps.replace(candidate: 'ws/l1.new', previous: 'ws/l1.old');
    expect(w.log, [
      'upload ws/l1.new',
      'publish ws/l1.new',
      'remove ws/l1.old',
    ]);
    expect(w.reference, 'ws/l1.new');
    expect(w.objects, {'ws/l1.new'});
  });

  test('a failed upload leaves the old image referenced and intact', () async {
    final w = _World()..failAt = 'upload';
    await expectLater(
      w.steps.replace(candidate: 'ws/l1.new', previous: 'ws/l1.old'),
      throwsStateError,
    );
    expect(w.reference, 'ws/l1.old');
    expect(w.objects, contains('ws/l1.old'));
    expect(w.dangling, isFalse);
  });

  test('a failed reference update keeps BOTH objects: the update may have '
      'committed', () async {
    final w = _World()..failAt = 'publish';
    await expectLater(
      w.steps.replace(candidate: 'ws/l1.new', previous: 'ws/l1.old'),
      throwsStateError,
    );
    expect(w.objects, containsAll(['ws/l1.old', 'ws/l1.new']));
    expect(w.log, isNot(contains('remove ws/l1.new')));
    expect(w.dangling, isFalse);
  });

  test(
    'a failed removal of the old object is a leftover, not a failure',
    () async {
      final w = _World()..failAt = 'remove';
      await w.steps.replace(candidate: 'ws/l1.new', previous: 'ws/l1.old');
      expect(w.reference, 'ws/l1.new');
      expect(w.leftovers, ['ws/l1.old']);
    },
  );

  test('clear: the reference first, then the object', () async {
    final w = _World();
    await w.steps.clear(previous: 'ws/l1.old');
    expect(w.log, ['publish null', 'remove ws/l1.old']);
    expect(w.reference, isNull);
  });

  test('a failed clear removes nothing', () async {
    final w = _World()..failAt = 'publish';
    await expectLater(w.steps.clear(previous: 'ws/l1.old'), throwsStateError);
    expect(w.objects, contains('ws/l1.old'));
    expect(w.dangling, isFalse);
  });
}

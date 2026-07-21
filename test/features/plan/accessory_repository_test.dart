// SPDX-License-Identifier: 0BSD
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_accessory_repository.dart';

void main() {
  group('accessory catalog contract (#166)', () {
    test('fetchAccessories orders by sort_order, then name', () async {
      final repo = FakeAccessoryRepository();
      await repo.createAccessory('ws-1', name: 'Zebra lamp', sortOrder: 0);
      await repo.createAccessory('ws-1', name: 'Monitor', sortOrder: 1);
      await repo.createAccessory('ws-1', name: 'Anglepoise', sortOrder: 0);

      final names =
          (await repo.fetchAccessories('ws-1')).map((a) => a.name).toList();
      expect(names, ['Anglepoise', 'Zebra lamp', 'Monitor']);
    });

    test('fetchAccessories is workspace-scoped', () async {
      final repo = FakeAccessoryRepository();
      await repo.createAccessory('ws-1', name: 'Monitor');
      await repo.createAccessory('ws-2', name: 'Standing desk');

      final names =
          (await repo.fetchAccessories('ws-1')).map((a) => a.name).toList();
      expect(names, ['Monitor']);
    });

    test('deactivate hides from the default listing but keeps the row',
        () async {
      final repo = FakeAccessoryRepository();
      final monitor = await repo.createAccessory('ws-1', name: 'Monitor');
      await repo.createAccessory('ws-1', name: 'Standing desk');

      final updated = await repo.updateAccessory(monitor.id, active: false);
      expect(updated.active, isFalse);

      final active = await repo.fetchAccessories('ws-1');
      expect(active.map((a) => a.name), ['Standing desk']);

      final all = await repo.fetchAccessories('ws-1', includeInactive: true);
      expect(all.map((a) => a.name), containsAll(['Monitor', 'Standing desk']));
    });

    test('updateAccessory patches only the given fields', () async {
      final repo = FakeAccessoryRepository();
      final monitor = await repo.createAccessory(
        'ws-1',
        name: 'Monitor',
        supplementCents: 100,
        sortOrder: 3,
      );

      final updated =
          await repo.updateAccessory(monitor.id, supplementCents: 250);
      expect(updated.name, 'Monitor');
      expect(updated.supplementCents, 250);
      expect(updated.active, isTrue);
      expect(updated.sortOrder, 3);
    });

    test('duplicate name in the same workspace is rejected', () async {
      final repo = FakeAccessoryRepository();
      await repo.createAccessory('ws-1', name: 'Monitor');
      expect(
        () => repo.createAccessory('ws-1', name: 'Monitor'),
        throwsStateError,
      );
      // ...but the same name is fine in another workspace.
      await repo.createAccessory('ws-2', name: 'Monitor');
    });
  });

  group('seat accessory assignment contract (#166)', () {
    test('setSeatAccessories replaces the whole set', () async {
      final repo = FakeAccessoryRepository();
      final monitor = await repo.createAccessory('ws-1', name: 'Monitor');
      final dock = await repo.createAccessory('ws-1', name: 'Dock');
      final desk = await repo.createAccessory('ws-1', name: 'Standing desk');

      await repo.setSeatAccessories('seat-1', {monitor.id, dock.id});
      expect(
        (await repo.fetchSeatAccessories('ws-1'))['seat-1'],
        {monitor.id, dock.id},
      );

      await repo.setSeatAccessories('seat-1', {desk.id});
      expect((await repo.fetchSeatAccessories('ws-1'))['seat-1'], {desk.id});
    });

    test('an empty set clears the seat', () async {
      final repo = FakeAccessoryRepository();
      final monitor = await repo.createAccessory('ws-1', name: 'Monitor');
      await repo.setSeatAccessories('seat-1', {monitor.id});

      await repo.setSeatAccessories('seat-1', const {});
      expect(await repo.fetchSeatAccessories('ws-1'), isEmpty);
    });

    test('fetchSeatAccessories is workspace-scoped', () async {
      final repo = FakeAccessoryRepository();
      final monitor = await repo.createAccessory('ws-1', name: 'Monitor');
      final other = await repo.createAccessory('ws-2', name: 'Monitor');
      await repo.setSeatAccessories('seat-1', {monitor.id});
      await repo.setSeatAccessories('seat-2', {other.id});

      expect(await repo.fetchSeatAccessories('ws-1'), {
        'seat-1': {monitor.id},
      });
      expect(await repo.fetchSeatAccessories('ws-2'), {
        'seat-2': {other.id},
      });
    });

    test('unknown accessory ids are rejected', () async {
      final repo = FakeAccessoryRepository();
      expect(
        () => repo.setSeatAccessories('seat-1', {'accessory-nope'}),
        throwsStateError,
      );
    });
  });
}

// SPDX-License-Identifier: MIT
import 'package:deskilo/features/plan/domain/accessory.dart';
import 'package:deskilo/features/plan/domain/accessory_repository.dart';

/// In-memory [AccessoryRepository] (fakes over mocks).
class FakeAccessoryRepository implements AccessoryRepository {
  final accessories = <Accessory>[];

  /// seat id → assigned accessory ids (all workspaces mixed, like the
  /// real table; [fetchSeatAccessories] filters by workspace).
  final seatAccessories = <String, Set<String>>{};

  var _nextId = 1;

  /// Seeds a small catalog: an active monitor with a supplement, an
  /// active standing desk, and a deactivated dock.
  void seedSmallCatalog({String workspaceId = 'ws-1'}) {
    accessories.addAll([
      Accessory(
        id: 'accessory-${_nextId++}',
        workspaceId: workspaceId,
        name: 'Monitor',
        supplementCents: 100,
        active: true,
        sortOrder: 0,
      ),
      Accessory(
        id: 'accessory-${_nextId++}',
        workspaceId: workspaceId,
        name: 'Standing desk',
        supplementCents: 0,
        active: true,
        sortOrder: 1,
      ),
      Accessory(
        id: 'accessory-${_nextId++}',
        workspaceId: workspaceId,
        name: 'Docking station',
        supplementCents: 50,
        active: false,
        sortOrder: 2,
      ),
    ]);
  }

  @override
  Future<List<Accessory>> fetchAccessories(
    String workspaceId, {
    bool includeInactive = false,
  }) async =>
      accessories
          .where((a) =>
              a.workspaceId == workspaceId && (includeInactive || a.active))
          .toList()
        ..sort((a, b) {
          final bySortOrder = a.sortOrder.compareTo(b.sortOrder);
          return bySortOrder != 0 ? bySortOrder : a.name.compareTo(b.name);
        });

  @override
  Future<Accessory> createAccessory(
    String workspaceId, {
    required String name,
    int supplementCents = 0,
    int sortOrder = 0,
  }) async {
    if (accessories
        .any((a) => a.workspaceId == workspaceId && a.name == name)) {
      throw StateError('duplicate accessory name in workspace');
    }
    final accessory = Accessory(
      id: 'accessory-${_nextId++}',
      workspaceId: workspaceId,
      name: name,
      supplementCents: supplementCents,
      active: true,
      sortOrder: sortOrder,
    );
    accessories.add(accessory);
    return accessory;
  }

  @override
  Future<Accessory> updateAccessory(
    String accessoryId, {
    String? name,
    int? supplementCents,
    bool? active,
    int? sortOrder,
  }) async {
    final i = accessories.indexWhere((a) => a.id == accessoryId);
    if (i < 0) throw StateError('unknown accessory $accessoryId');
    var updated = accessories[i];
    if (name != null) updated = updated.copyWith(name: name);
    if (supplementCents != null) {
      updated = updated.copyWith(supplementCents: supplementCents);
    }
    if (active != null) updated = updated.copyWith(active: active);
    if (sortOrder != null) updated = updated.copyWith(sortOrder: sortOrder);
    accessories[i] = updated;
    return updated;
  }

  @override
  Future<Map<String, Set<String>>> fetchSeatAccessories(
    String workspaceId,
  ) async {
    final workspaceAccessoryIds = accessories
        .where((a) => a.workspaceId == workspaceId)
        .map((a) => a.id)
        .toSet();
    return {
      for (final entry in seatAccessories.entries)
        if (entry.value.any(workspaceAccessoryIds.contains))
          entry.key: entry.value.intersection(workspaceAccessoryIds),
    };
  }

  @override
  Future<void> setSeatAccessories(
    String seatId,
    Set<String> accessoryIds,
  ) async {
    final known = accessories.map((a) => a.id).toSet();
    final unknown = accessoryIds.difference(known);
    if (unknown.isNotEmpty) {
      throw StateError('unknown accessories: ${unknown.join(', ')}');
    }
    if (accessoryIds.isEmpty) {
      seatAccessories.remove(seatId);
    } else {
      seatAccessories[seatId] = Set.of(accessoryIds);
    }
  }
}

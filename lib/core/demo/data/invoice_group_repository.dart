// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 (part 2) — my groups of invoices, kept in memory: the Demo's and the
// tests'. The same rules as 0800: a name is trimmed, 1 to 80 characters,
// used once per person whatever its case; an invoice is in a group once.
import '../../../features/money/domain/invoice_groups.dart';

class FakeInvoiceGroupRepository implements InvoiceGroupRepository {
  FakeInvoiceGroupRepository({List<InvoiceGroup> groups = const []})
    : _groups = [
        for (final g in groups) _Group(g.id, g.name, [...g.items]),
      ];

  final List<_Group> _groups;
  int _ids = 0;

  /// Every call fails with this, when set (a source that does not answer).
  Exception? failure;

  void _check() {
    if (failure case final f?) throw f;
  }

  @override
  Future<List<InvoiceGroup>> groups() async {
    _check();
    return [
      for (final g in [
        ..._groups,
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())))
        InvoiceGroup(id: g.id, name: g.name, items: List.unmodifiable(g.items)),
    ];
  }

  String _valid(String name, {String? except}) {
    final checked = invoiceGroupName(name);
    if (checked.name == null || checked.name != name) {
      throw const InvoiceGroupRefused(InvoiceGroupRefusal.nameShape);
    }
    if (_groups.any(
      (g) => g.id != except && g.name.toLowerCase() == name.toLowerCase(),
    )) {
      throw const InvoiceGroupRefused(InvoiceGroupRefusal.nameTaken);
    }
    return name;
  }

  @override
  Future<String> create(String name) async {
    _check();
    final group = _Group('group-${++_ids}', _valid(name), []);
    _groups.add(group);
    return group.id;
  }

  @override
  Future<void> rename(String groupId, String name) async {
    _check();
    _of(groupId)?.name = _valid(name, except: groupId);
  }

  @override
  Future<void> delete(String groupId) async {
    _check();
    _groups.removeWhere((g) => g.id == groupId);
  }

  @override
  Future<void> add(String groupId, InvoiceRef ref, String number) async {
    _check();
    final group = _of(groupId);
    if (group == null || group.items.any((i) => i.ref == ref)) return;
    group.items.add(InvoiceGroupItem(ref, number));
  }

  @override
  Future<void> remove(String groupId, InvoiceRef ref) async {
    _check();
    _of(groupId)?.items.removeWhere((i) => i.ref == ref);
  }

  _Group? _of(String id) => _groups.where((g) => g.id == id).firstOrNull;
}

class _Group {
  _Group(this.id, this.name, this.items);
  final String id;
  String name;
  final List<InvoiceGroupItem> items;
}

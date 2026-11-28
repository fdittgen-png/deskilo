// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4518 -- the contacts, roles and terms of the suppliers kept in memory (the Demo's and the tests'), under the rules the server applies:
// a contact has a name, a role of the business (an active one, or the one it holds) and a valid e-mail; the preferred one has an e-mail, is
// not retired, and is the only preferred one of its supplier; a role has a name kept once among the active ones; nothing is deleted.
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/codes/dk_code.dart';
import '../domain/supplier_contact.dart';

class InMemorySupplierContacts implements SupplierContactRepository {
  InMemorySupplierContacts();

  final Map<String, List<SupplierContactRole>> _roles = {};
  final Map<String, List<SupplierContact>> _contacts = {};
  final Map<String, SupplierTerms> _terms = {};
  int _next = 0;

  static final _email = RegExp(r'^[^\s@<>",;()\[\]\\]+@[^\s@<>",;()\[\]\\]+\.[^\s@<>",;()\[\]\\]+$');

  List<SupplierContactRole> _rolesOf(String ws) => _roles.putIfAbsent(ws, () => [
    for (final (i, code) in BuiltInContactRole.codes.indexed)
      SupplierContactRole(id: '$ws-role-$code', code: code, label: '', sortOrder: (i + 1) * 10, builtIn: true, retired: false),
  ]);

  PostgrestException _refused(String detail) => PostgrestException(message: 'supplier contact: $detail', code: DkCode.dkx02, details: detail);

  /// Puts the contact in place without the rules (the Demo's seed).
  void seed(String ws, SupplierContact contact) => _contacts.putIfAbsent('$ws|${contact.supplierId}', () => []).add(contact);

  @override
  Future<List<SupplierContactRole>> roles(String workspaceId) async => [
    for (final r in [..._rolesOf(workspaceId)]..sort((a, b) => a.sortOrder != b.sortOrder ? a.sortOrder.compareTo(b.sortOrder) : a.code.compareTo(b.code))) r,
  ];

  @override
  Future<List<SupplierContact>> contacts(String workspaceId, String supplierId) async => [...?_contacts['$workspaceId|$supplierId']];

  @override
  Future<SupplierTerms> terms(String workspaceId, String supplierId) async => _terms['$workspaceId|$supplierId'] ?? SupplierTerms.none;

  @override
  Future<void> saveRole(String workspaceId, {String? id, required String label, int? sortOrder, required String requestId}) async {
    final all = _rolesOf(workspaceId);
    SupplierContactRole? held;
    for (final r in all) {
      if (r.id == id) held = r;
    }
    if (id != null && held == null) throw _refused('role_unknown');
    final name = label.trim();
    if (name.length > 60) throw _refused('label_too_long');
    if (name.isEmpty && !(held?.builtIn ?? false)) throw _refused('label_required');
    if (name.isNotEmpty && all.any((r) => !r.retired && r.id != id && r.label.trim().toLowerCase() == name.toLowerCase())) throw _refused('label_taken');
    if (held != null) {
      all[all.indexOf(held)] = held.copyWith(label: name, sortOrder: sortOrder);
      return;
    }
    all.add(SupplierContactRole(id: '$workspaceId-role-${_next++}', code: 'r_${(_next + 1000).toRadixString(16)}', label: name, sortOrder: sortOrder ?? 1000, builtIn: false, retired: false));
  }

  @override
  Future<void> setRoleRetired(String workspaceId, String id, {required bool retired, required String requestId}) async {
    final all = _rolesOf(workspaceId);
    SupplierContactRole? held;
    for (final r in all) {
      if (r.id == id) held = r;
    }
    if (held == null) throw _refused('role_unknown');
    if (!retired && held.retired && held.label.trim().isNotEmpty && all.any((o) => !o.retired && o.id != id && o.label.trim().toLowerCase() == held!.label.trim().toLowerCase())) {
      throw _refused('label_taken');
    }
    all[all.indexOf(held)] = held.copyWith(retired: retired);
  }

  @override
  Future<void> saveContact(
    String workspaceId, {
    String? id,
    required String supplierId,
    required String name,
    required String roleId,
    required String email,
    required String phone,
    required String note,
    required bool preferred,
    required String requestId,
  }) async {
    final list = _contacts.putIfAbsent('$workspaceId|$supplierId', () => []);
    SupplierContact? held;
    for (final c in list) {
      if (c.id == id) held = c;
    }
    if (id != null && held == null) throw _refused('contact_unknown');
    final who = name.trim();
    final mail = email.trim();
    if (who.isEmpty || who.length > 120) throw _refused('name_required');
    if (mail.isNotEmpty && !_email.hasMatch(mail)) throw _refused('email_invalid');
    final roles = _rolesOf(workspaceId);
    if (!roles.any((r) => r.id == roleId && (!r.retired || r.id == held?.roleId))) throw _refused('role_unknown');
    if (preferred && mail.isEmpty) throw _refused('preferred_needs_email');
    if (preferred && (held?.retired ?? false)) throw _refused('preferred_retired');
    if (preferred) {
      for (final (i, c) in list.indexed) {
        if (c.preferred && c.id != held?.id) {
          list[i] = SupplierContact(id: c.id, supplierId: c.supplierId, name: c.name, roleId: c.roleId, email: c.email, phone: c.phone, note: c.note, retired: c.retired);
        }
      }
    }
    final made = SupplierContact(
      id: held?.id ?? '$workspaceId-contact-${_next++}',
      supplierId: supplierId,
      name: who,
      roleId: roleId,
      email: mail,
      phone: phone.trim(),
      note: note.trim(),
      preferred: preferred,
      retired: held?.retired ?? false,
    );
    if (held == null) {
      list.add(made);
    } else {
      list[list.indexOf(held)] = made;
    }
  }

  @override
  Future<void> setContactRetired(String workspaceId, String id, {required bool retired, required String requestId}) async {
    for (final list in _contacts.entries.where((e) => e.key.startsWith('$workspaceId|')).map((e) => e.value)) {
      for (final (i, c) in list.indexed) {
        if (c.id == id) {
          list[i] = SupplierContact(
            id: c.id,
            supplierId: c.supplierId,
            name: c.name,
            roleId: c.roleId,
            email: c.email,
            phone: c.phone,
            note: c.note,
            preferred: !retired && c.preferred,
            retired: retired,
          );
          return;
        }
      }
    }
    throw _refused('contact_unknown');
  }

  @override
  Future<void> saveTerms(String workspaceId, String supplierId, SupplierTerms terms, {required String requestId}) async {
    final c = terms.orderCurrency;
    if (c != null && !RegExp(r'^[A-Z]{3}$').hasMatch(c)) throw _refused('currency_invalid');
    for (final d in [terms.paymentTermDays, terms.orderLeadDays]) {
      if (d != null && (d < 0 || d > 365)) throw _refused('term_invalid');
    }
    _terms['$workspaceId|$supplierId'] = terms;
  }
}

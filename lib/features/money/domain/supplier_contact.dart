// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4518 (STK-11) -- the people of a supplier, each with a role the business keeps, one of them its preferred purchasing contact; and what
// the business agreed once with the supplier: the currency its orders are placed in, the days a bill is due after its date, the days an
// order expects its goods after it is sent. A new order and a new bill start from them; what was sent keeps what it was sent with.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// The codes of the roles every business starts with.
abstract final class BuiltInContactRole {
  static const orders = 'orders';
  static const invoices = 'invoices';
  static const delivery = 'delivery';
  static const accounting = 'accounting';
  static const other = 'other';
  static const codes = [orders, invoices, delivery, accounting, other];
}

/// One role of a business's supplier contacts.
class SupplierContactRole {
  const SupplierContactRole({required this.id, required this.code, required this.label, required this.sortOrder, required this.builtIn, required this.retired});

  factory SupplierContactRole.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'supplier_contact_roles');
    return SupplierContactRole(
      id: r.string('id'),
      code: r.string('code'),
      label: r.stringOr('label'),
      sortOrder: r.integer('sort_order'),
      builtIn: r.isTrue('built_in'),
      retired: r.isTrue('retired') || r.stringOrNull('retired_at') != null,
    );
  }

  final String id;
  final String code;

  /// The business's own words; empty for a built-in role that keeps the app's.
  final String label;
  final int sortOrder;
  final bool builtIn;
  final bool retired;

  SupplierContactRole copyWith({String? label, int? sortOrder, bool? retired}) => SupplierContactRole(
    id: id,
    code: code,
    label: label ?? this.label,
    sortOrder: sortOrder ?? this.sortOrder,
    builtIn: builtIn,
    retired: retired ?? this.retired,
  );
}

/// One contact of one supplier.
class SupplierContact {
  const SupplierContact({
    required this.id,
    required this.supplierId,
    required this.name,
    required this.roleId,
    this.email = '',
    this.phone = '',
    this.note = '',
    this.preferred = false,
    this.retired = false,
  });

  factory SupplierContact.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'supplier_contacts');
    return SupplierContact(
      id: r.string('id'),
      supplierId: r.string('supplier_id'),
      name: r.stringOr('name'),
      roleId: r.string('role_id'),
      email: r.stringOr('email'),
      phone: r.stringOr('phone'),
      note: r.stringOr('note'),
      preferred: r.isTrue('preferred'),
      retired: r.isTrue('retired') || r.stringOrNull('retired_at') != null,
    );
  }

  final String id;
  final String supplierId;
  final String name;
  final String roleId;
  final String email;
  final String phone;
  final String note;

  /// The contact a new order is addressed to.
  final bool preferred;
  final bool retired;
}

/// What a supplier's orders and bills start from; each is null where none is stated.
class SupplierTerms {
  const SupplierTerms({this.orderCurrency, this.paymentTermDays, this.orderLeadDays});

  factory SupplierTerms.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'suppliers');
    return SupplierTerms(
      orderCurrency: r.stringOrNull('order_currency'),
      paymentTermDays: r.intOrNull('payment_term_days'),
      orderLeadDays: r.intOrNull('order_lead_days'),
    );
  }

  static const none = SupplierTerms();

  final String? orderCurrency;
  final int? paymentTermDays;
  final int? orderLeadDays;
}

/// Reads and keeps the contacts, the contact roles and the terms of the suppliers of a business.
abstract interface class SupplierContactRepository {
  /// Every role of the business, active and retired, in its order.
  Future<List<SupplierContactRole>> roles(String workspaceId);

  /// Every contact of [supplierId], active and retired.
  Future<List<SupplierContact>> contacts(String workspaceId, String supplierId);

  /// What [supplierId] agreed once.
  Future<SupplierTerms> terms(String workspaceId, String supplierId);

  /// A new role (no [id]) or the new name or place of [id]; an empty [label] on a built-in role gives the app's words back.
  Future<void> saveRole(String workspaceId, {String? id, required String label, int? sortOrder, required String requestId});

  /// Retires the role [id], or brings it back.
  Future<void> setRoleRetired(String workspaceId, String id, {required bool retired, required String requestId});

  /// A new contact (no [id]) or the changes of [id]; making it [preferred] frees the supplier's other preferred contact.
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
  });

  /// Retires the contact [id], or brings it back.
  Future<void> setContactRetired(String workspaceId, String id, {required bool retired, required String requestId});

  /// The terms of [supplierId]: each given or null (none stated).
  Future<void> saveTerms(String workspaceId, String supplierId, SupplierTerms terms, {required String requestId});
}

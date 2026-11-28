// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4518 -- what a person who manages suppliers does to their contacts, the roles of those contacts and the terms agreed with them. The
// server decides; what it refused is told by one of a few reasons, never by its sentence.
import '../../../core/data/server_error.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/trace/guarded.dart';
import '../domain/supplier_contact.dart';

/// Why a change was not made.
enum SupplierContactProblem {
  /// Another active role already has the name.
  nameTaken,

  /// A role or a contact needs a name.
  nameRequired,

  /// The e-mail is not an address.
  emailInvalid,

  /// The preferred purchasing contact has an e-mail.
  preferredNeedsEmail,

  /// The currency or a term is out of range.
  termsInvalid,

  /// Anything else: no right, no connection, a role or a supplier that is not the business's.
  failed,
}

// the reasons the server names in the detail of its refusal (DKX02, 1003)
const _taken = 'label_taken';
const _required = 'label_required';
const _contactName = 'name_required';
const _email = 'email_invalid';
const _needsEmail = 'preferred_needs_email';
const _currency = 'currency_invalid';
const _term = 'term_invalid';

class SupplierContactCommands {
  const SupplierContactCommands(this._repository);

  final SupplierContactRepository _repository;

  Future<List<SupplierContactRole>> roles(String workspaceId) => _repository.roles(workspaceId);
  Future<List<SupplierContact>> contacts(String workspaceId, String supplierId) => _repository.contacts(workspaceId, supplierId);
  Future<SupplierTerms> terms(String workspaceId, String supplierId) => _repository.terms(workspaceId, supplierId);

  Future<SupplierContactProblem?> saveRole(String workspaceId, {String? id, required String label}) => _do(
    'save supplier contact role failed',
    () => _repository.saveRole(workspaceId, id: id, label: label.trim(), requestId: newRequestId()),
  );

  Future<SupplierContactProblem?> setRoleRetired(String workspaceId, String id, {required bool retired}) => _do(
    'retire supplier contact role failed',
    () => _repository.setRoleRetired(workspaceId, id, retired: retired, requestId: newRequestId()),
  );

  /// Moves the role at [from] of the active [active] to [to]: each one that is not at its place is saved with it.
  Future<SupplierContactProblem?> moveRole(String workspaceId, List<SupplierContactRole> active, int from, int to) => _do(
    'order supplier contact roles failed',
    () async {
      final moved = [...active];
      moved.insert(to, moved.removeAt(from));
      for (final (i, r) in moved.indexed) {
        if (r.sortOrder != (i + 1) * 10) {
          await _repository.saveRole(workspaceId, id: r.id, label: r.label, sortOrder: (i + 1) * 10, requestId: newRequestId());
        }
      }
    },
  );

  Future<SupplierContactProblem?> saveContact(
    String workspaceId, {
    String? id,
    required String supplierId,
    required String name,
    required String roleId,
    required String email,
    String phone = '',
    String note = '',
    bool preferred = false,
  }) => _do(
    'save supplier contact failed',
    () => _repository.saveContact(
      workspaceId,
      id: id,
      supplierId: supplierId,
      name: name,
      roleId: roleId,
      email: email,
      phone: phone,
      note: note,
      preferred: preferred,
      requestId: newRequestId(),
    ),
  );

  Future<SupplierContactProblem?> setContactRetired(String workspaceId, String id, {required bool retired}) => _do(
    'retire supplier contact failed',
    () => _repository.setContactRetired(workspaceId, id, retired: retired, requestId: newRequestId()),
  );

  Future<SupplierContactProblem?> saveTerms(String workspaceId, String supplierId, SupplierTerms terms) => _do(
    'save supplier terms failed',
    () => _repository.saveTerms(workspaceId, supplierId, terms, requestId: newRequestId()),
  );

  Future<SupplierContactProblem?> _do(String message, Future<void> Function() action) async {
    final problem = await guardSave(
      domain: 'money',
      message: message,
      action: action,
      problem: (e) => switch (serverErrorDetails(e)) {
        _taken => SupplierContactProblem.nameTaken.name,
        _required || _contactName => SupplierContactProblem.nameRequired.name,
        _email => SupplierContactProblem.emailInvalid.name,
        _needsEmail => SupplierContactProblem.preferredNeedsEmail.name,
        _currency || _term => SupplierContactProblem.termsInvalid.name,
        _ => SupplierContactProblem.failed.name,
      },
    );
    return problem == null ? null : SupplierContactProblem.values.byName(problem);
  }
}

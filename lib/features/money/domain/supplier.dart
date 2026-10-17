// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/json_reader.dart';

/// #2567 — whether a supplier is offered in pickers (`suppliers`, 0457).
enum SupplierStatus {
  active,
  archived;

  static SupplierStatus of(String? s) =>
      values.firstWhere((v) => v.name == s, orElse: () => active);
}

/// What a tax identifier names. A VAT-group identifier is shared by several
/// legal parties, so it is never enough to say two records are one payee.
enum SupplierIdKind {
  vat('vat'),
  vatGroup('vat_group');

  const SupplierIdKind(this.wire);

  final String wire;

  static SupplierIdKind of(String? s) =>
      values.firstWhere((v) => v.wire == s, orElse: () => vat);
}

/// One payee of the purchase side. It carries NO bank data: pickers read
/// this row, the bank revisions are a separate, manager-only read.
class Supplier {
  const Supplier({
    required this.id,
    required this.number,
    required this.name,
    this.taxIdEntered = '',
    this.taxIdentifier = '',
    this.taxIdKind = SupplierIdKind.vat,
    this.street = '',
    this.postalCode = '',
    this.city = '',
    this.countryCode = '',
    this.contact = '',
    this.status = SupplierStatus.active,
    this.bankRevision = 0,
  });

  factory Supplier.fromRow(Object? raw) {
    final r = JsonReader.of(raw, context: 'suppliers');
    return Supplier(
      id: r.string('id'),
      number: r.stringOr('supplier_number'),
      name: r.stringOr('name'),
      taxIdEntered: r.stringOr('tax_id_entered'),
      taxIdentifier: r.stringOr('tax_identifier'),
      taxIdKind: SupplierIdKind.of(r.stringOrNull('tax_id_kind')),
      street: r.stringOr('street'),
      postalCode: r.stringOr('postal_code'),
      city: r.stringOr('city'),
      countryCode: r.stringOr('country_code'),
      contact: r.stringOr('contact'),
      status: SupplierStatus.of(r.stringOrNull('status')),
      bankRevision: r.intOrNull('bank_revision') ?? 0,
    );
  }

  final String id;

  /// Unique per workspace; the accounting consumers validate it against
  /// their own rule.
  final String number;
  final String name;

  /// The identifier as a person typed it.
  final String taxIdEntered;

  /// The canonical form, only when it verified against its jurisdiction's
  /// pattern; empty otherwise. This is the merge key.
  final String taxIdentifier;
  final SupplierIdKind taxIdKind;
  final String street;
  final String postalCode;
  final String city;
  final String countryCode;
  final String contact;
  final SupplierStatus status;
  final int bankRevision;

  bool get isActive => status == SupplierStatus.active;
  bool get isVerified => taxIdentifier.isNotEmpty;
}

/// What a person types to create or change a supplier. A blank [number]
/// asks for the next free one.
class SupplierDraft {
  const SupplierDraft({
    required this.name,
    this.id,
    this.number = '',
    this.taxId = '',
    this.taxIdKind = SupplierIdKind.vat,
    this.street = '',
    this.postalCode = '',
    this.city = '',
    this.countryCode = '',
    this.contact = '',
  });

  factory SupplierDraft.of(Supplier s) => SupplierDraft(
    id: s.id,
    name: s.name,
    number: s.number,
    taxId: s.taxIdEntered,
    taxIdKind: s.taxIdKind,
    street: s.street,
    postalCode: s.postalCode,
    city: s.city,
    countryCode: s.countryCode,
    contact: s.contact,
  );

  final String? id;
  final String name;
  final String number;
  final String taxId;
  final SupplierIdKind taxIdKind;
  final String street;
  final String postalCode;
  final String city;
  final String countryCode;
  final String contact;
}

/// Why a source record was not linked on its own.
enum SupplierReviewReason {
  missingIdentifier('missing_identifier'),
  unverifiedIdentifier('unverified_identifier'),
  groupIdentifier('group_identifier');

  const SupplierReviewReason(this.wire);

  final String wire;

  static SupplierReviewReason of(String? s) =>
      values.firstWhere((v) => v.wire == s, orElse: () => unverifiedIdentifier);
}

/// A source record (an inbox invoice) waiting for a person to say which
/// supplier it belongs to. The record itself is untouched meanwhile.
class SupplierReview {
  const SupplierReview({
    required this.id,
    required this.reason,
    required this.sourceName,
    required this.sourceIdentifier,
    this.candidateIds = const [],
  });

  factory SupplierReview.fromRow(Object? raw) {
    final r = JsonReader.of(raw, context: 'supplier_review_candidates');
    return SupplierReview(
      id: r.string('id'),
      reason: SupplierReviewReason.of(r.stringOrNull('reason')),
      sourceName: r.stringOr('source_name'),
      sourceIdentifier: r.stringOr('source_identifier'),
      candidateIds: r.strings('candidate_supplier_ids'),
    );
  }

  final String id;
  final SupplierReviewReason reason;
  final String sourceName;
  final String sourceIdentifier;
  final List<String> candidateIds;
}

/// The outcome the server recorded for one bank-detail revision.
enum BankValidation {
  valid,
  invalid,
  cleared;

  static BankValidation of(String? s) =>
      values.firstWhere((v) => v.name == s, orElse: () => invalid);
}

/// One revision of a supplier's bank details (`supplier_bank_revisions`).
class SupplierBankRevision {
  const SupplierBankRevision({
    required this.revision,
    required this.accountHolder,
    required this.iban,
    required this.bic,
    required this.validation,
    required this.detail,
    required this.changedAt,
  });

  factory SupplierBankRevision.fromRow(Object? raw) {
    final r = JsonReader.of(raw, context: 'supplier_bank_revisions');
    return SupplierBankRevision(
      revision: r.intOrNull('revision') ?? 0,
      accountHolder: r.stringOr('account_holder'),
      iban: r.stringOr('iban'),
      bic: r.stringOr('bic'),
      validation: BankValidation.of(r.stringOrNull('validation')),
      detail: r.stringOr('validation_detail'),
      changedAt: r.stringOr('changed_at'),
    );
  }

  final int revision;
  final String accountHolder;
  final String iban;
  final String bic;
  final BankValidation validation;
  final String detail;
  final String changedAt;
}

abstract interface class SupplierRepository {
  /// Every supplier of the workspace, archived ones included.
  Future<List<Supplier>> fetchSuppliers(String workspaceId);

  Future<List<SupplierReview>> fetchReviews(String workspaceId);

  /// Newest revision first. Manager-only on the server.
  Future<List<SupplierBankRevision>> fetchBankHistory(
    String workspaceId,
    String supplierId,
  );

  /// Creates or updates; returns the supplier id. Throws when the server
  /// refuses (a taken number or identifier, no permission, flag off).
  Future<String> save(String workspaceId, SupplierDraft draft);

  Future<void> setStatus(String supplierId, SupplierStatus status);

  /// Returns the current revision (unchanged when nothing changed).
  Future<int> setBank(
    String supplierId, {
    required String accountHolder,
    required String iban,
    required String bic,
  });

  /// Links the review's source to [supplierId], or to a new supplier made
  /// from the source's own text when null.
  Future<String> resolveReview(String reviewId, String? supplierId);
}

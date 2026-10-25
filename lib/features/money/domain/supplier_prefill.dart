// SPDX-License-Identifier: AGPL-3.0-or-later
//
// From a registry's answer to the supplier form: which field holds what
// and why (so the review step can say it), and whether the identifier
// already names a supplier of the workspace (so no second one is made).
import 'company_lookup.dart';
import 'supplier.dart';

/// Why a field of the review step holds what it holds.
enum FieldProvenance {
  /// The registry returned it.
  retrieved,

  /// The registry validated it (the identifier).
  validated,

  /// The registry returned nothing for it; what is there was typed.
  notReturned,

  /// The person changed it after the lookup.
  userEdited,
}

/// The review step's start: the draft, where each field came from, and
/// the answer that made it.
class SupplierPrefill {
  const SupplierPrefill({
    required this.draft,
    required this.provenance,
    required this.request,
    required this.result,
  });

  final SupplierDraft draft;

  /// Field key of the supplier form (`name`, `street`, `postalCode`,
  /// `city`, `countryCode`, `taxId`) → provenance.
  final Map<String, FieldProvenance> provenance;
  final CompanyLookupRequest request;
  final CompanyLookupResult result;
}

/// The field keys of the supplier form a registry can fill, by field.
const Map<CompanyField, String> _supplierFieldKeys = {
  CompanyField.legalName: 'name',
  CompanyField.street: 'street',
  CompanyField.postalCode: 'postalCode',
  CompanyField.city: 'city',
  CompanyField.countryCode: 'countryCode',
};

/// Builds the review step from an answer: a returned field replaces the
/// typed one and is marked retrieved; a field the registry did not return
/// keeps what was typed and is marked so; the identifier is marked
/// validated only when the registry said so. Nothing is invented.
SupplierPrefill prefillFromLookup({
  required CompanyLookupRequest request,
  required CompanyLookupResult result,
  required CompanyLookupCapability capability,
  SupplierDraft base = const SupplierDraft(name: ''),
}) {
  final provenance = <String, FieldProvenance>{};
  String pick(CompanyField field, String typed) {
    final key = _supplierFieldKeys[field]!;
    final value = result.fields[field];
    if (value != null) {
      provenance[key] = FieldProvenance.retrieved;
      return value;
    }
    if (capability.fields.contains(field)) {
      provenance[key] = FieldProvenance.notReturned;
    }
    return typed;
  }

  if (result.validation == IdentifierValidation.validated) {
    provenance['taxId'] = FieldProvenance.validated;
  }
  final country = pick(CompanyField.countryCode, base.countryCode);
  return SupplierPrefill(
    draft: SupplierDraft(
      id: base.id,
      name: pick(CompanyField.legalName, base.name),
      number: base.number,
      taxId: request.identifier.display,
      taxIdKind: base.taxIdKind,
      street: pick(CompanyField.street, base.street),
      postalCode: pick(CompanyField.postalCode, base.postalCode),
      city: pick(CompanyField.city, base.city),
      countryCode: country.isEmpty ? request.countryCode : country,
      contact: base.contact,
    ),
    provenance: provenance,
    request: request,
    result: result,
  );
}

/// The supplier that already carries [identifier] as a VAT identifier:
/// the server's verified key or the typed text, compared without
/// separators. A VAT-group identifier is shared by several legal parties,
/// so it never names a duplicate; a name alone never does either.
/// [exceptId] is the supplier being edited, which never duplicates itself.
Supplier? supplierWithIdentifier(
  Iterable<Supplier> suppliers,
  CompanyIdentifier identifier, {
  String? exceptId,
}) {
  final keys = {
    identifier.canonical,
    '${identifier.countryCode}${identifier.body}',
  };
  for (final s in suppliers) {
    if (s.taxIdKind != SupplierIdKind.vat || s.id == exceptId) continue;
    final typed = compactIdentifier(s.taxIdEntered);
    if (keys.contains(s.taxIdentifier) || keys.contains(typed)) return s;
  }
  return null;
}

/// The supplier a draft would duplicate by its VAT identifier, read the way
/// the lookup reads it (separators, case, prefix from the country); null for
/// a VAT group, an empty or unreadable identifier, or no match. The server
/// refuses the same duplicate on save; this names it before the attempt.
Supplier? supplierDuplicateOf(
  Iterable<Supplier> suppliers,
  SupplierDraft draft,
) {
  if (draft.taxIdKind != SupplierIdKind.vat) return null;
  final identifier = normalizeCompanyIdentifier(
    draft.taxId,
    country: draft.countryCode,
  );
  if (identifier == null) return null;
  return supplierWithIdentifier(suppliers, identifier, exceptId: draft.id);
}

final _notLetterOrDigit = RegExp(r'[^\p{L}\p{N}]', unicode: true);

/// [name] as names are compared: lower case, letters and digits only.
String _nameKey(String name) =>
    name.toLowerCase().replaceAll(_notLetterOrDigit, '');

/// Another supplier whose name reads the same as [draft]'s once case,
/// spaces and punctuation are set aside — a caution, never a block: two
/// companies may share a name, so the person decides. A supplier that
/// already carries the same identifier is the duplicate, not this.
Supplier? supplierWithSimilarName(
  Iterable<Supplier> suppliers,
  SupplierDraft draft,
) {
  final key = _nameKey(draft.name);
  if (key.isEmpty) return null;
  for (final s in suppliers) {
    if (s.id == draft.id) continue;
    if (_nameKey(s.name) == key) return s;
  }
  return null;
}

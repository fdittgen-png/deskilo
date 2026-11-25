// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 A2 -- a billing customer: someone the business invoices, with or
// without an account. This is the seller's record of who is billed (billed name
// or company, postal identity, tax identifiers, delivery contact), kept apart
// from the login contact and from any profile; an invoice issued to it keeps its
// own immutable snapshot. Pure Dart: the rules a form checks before it sends are
// here, and the server's own refusals come back as [BillingCustomerRefusal].
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../core/failure/app_failure.dart';

/// What a customer is billed under, and how to reach them.
class BillingPartyDraft {
  const BillingPartyDraft({
    this.courtesy = '',
    this.firstName = '',
    this.lastName = '',
    this.company = '',
    this.street = '',
    this.postalCode = '',
    this.city = '',
    this.subdivision = '',
    this.countryCode = '',
    this.vatId = '',
    this.legalId = '',
    this.email = '',
    this.phone = '',
  });

  final String courtesy;
  final String firstName;
  final String lastName;
  final String company;
  final String street;
  final String postalCode;
  final String city;
  final String subdivision;
  final String countryCode;
  final String vatId;
  final String legalId;
  final String email;
  final String phone;

  /// The wire object of the server's `billing_party_clean`: every field, as text.
  Map<String, String> toWire() => {
    'courtesy': courtesy.trim(),
    'first_name': firstName.trim(),
    'last_name': lastName.trim(),
    'company': company.trim(),
    'street': street.trim(),
    'postal_code': postalCode.trim(),
    'city': city.trim(),
    'subdivision': subdivision.trim(),
    'country_code': countryCode.trim().toUpperCase(),
    'vat_id': vatId.trim(),
    'legal_id': legalId.trim(),
    'email': email.trim(),
    'phone': phone.trim(),
  };
}

/// A billing customer as the business reads it.
class BillingParty {
  const BillingParty({
    required this.subjectId,
    required this.revision,
    required this.draft,
    this.status = 'customer',
    this.capacity,
  });

  /// Tolerant of a field a later server adds; a missing one reads as empty.
  factory BillingParty.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'billing customer');
    final capacity = r.stringOrNull('capacity');
    return BillingParty(
      subjectId: r.string('subject_id'),
      revision: r.integer('revision'),
      status: r.stringOr('status', 'customer'),
      capacity: capacity == 'business' || capacity == 'consumer'
          ? capacity
          : null,
      draft: BillingPartyDraft(
        courtesy: r.stringOr('courtesy'),
        firstName: r.stringOr('first_name'),
        lastName: r.stringOr('last_name'),
        company: r.stringOr('company'),
        street: r.stringOr('street'),
        postalCode: r.stringOr('postal_code'),
        city: r.stringOr('city'),
        subdivision: r.stringOr('subdivision'),
        countryCode: r.stringOr('country_code'),
        vatId: r.stringOr('vat_id'),
        legalId: r.stringOr('legal_id'),
        email: r.stringOr('email'),
        phone: r.stringOr('phone'),
      ),
    );
  }

  /// The seller-local financial subject (`members.id`): what invoices and the
  /// ledger key on.
  final String subjectId;

  /// The revision the editor read: an edit is refused when it has moved.
  final int revision;
  final BillingPartyDraft draft;

  /// `customer` for a billing-only subject.
  final String status;

  /// `business`, `consumer`, or null while nobody stated it.
  final String? capacity;

  /// The company, else the person: what a list and an invoice call them.
  String get displayName {
    final company = draft.company.trim();
    if (company.isNotEmpty) return company;
    return '${draft.firstName} ${draft.lastName}'.trim();
  }
}

/// A problem a form shows under its own field.
enum BillingPartyProblem {
  nameMissing,
  countryInvalid,
  vatIdInvalid,
  emailInvalid,
}

final RegExp _country = RegExp(r'^[A-Za-z]{2}$');
final RegExp _vat = RegExp(r'^[A-Za-z]{2}[A-Za-z0-9+*.]{2,14}$');
final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// The rules a draft passes before it is sent. Pure: nothing here asks the
/// server. A VAT number is checked for shape only; it is never treated as
/// verified.
Map<String, BillingPartyProblem> validateBillingParty(BillingPartyDraft d) {
  final problems = <String, BillingPartyProblem>{};
  if (d.company.trim().isEmpty &&
      d.firstName.trim().isEmpty &&
      d.lastName.trim().isEmpty) {
    problems['company'] = BillingPartyProblem.nameMissing;
  }
  final country = d.countryCode.trim();
  if (country.isNotEmpty && !_country.hasMatch(country)) {
    problems['country'] = BillingPartyProblem.countryInvalid;
  }
  final vat = d.vatId.replaceAll(' ', '');
  if (vat.isNotEmpty && !_vat.hasMatch(vat)) {
    problems['vat'] = BillingPartyProblem.vatIdInvalid;
  }
  final email = d.email.trim();
  if (email.isNotEmpty && !_email.hasMatch(email)) {
    problems['email'] = BillingPartyProblem.emailInvalid;
  }
  return problems;
}

/// Why the server refused, as the screen can say it.
enum BillingCustomerRefusalKind {
  /// The caller lacks the right (or is an assistant): nothing was written.
  notAllowed,

  /// The record changed since it was read.
  stale,

  /// The customer is not (or no longer) one of this business's.
  unknownCustomer,

  /// The server asked for a name or a company.
  nameNeeded,

  /// Anything else: shown with the screen's own sentence.
  other,
}

class BillingCustomerRefusal implements TypedRefusal {
  const BillingCustomerRefusal(this.kind, {this.cause});

  final BillingCustomerRefusalKind kind;
  final Object? cause;

  @override
  String toString() => 'BillingCustomerRefusal($kind)';
}

/// A draft that breaks a rule needing no server ([validateBillingParty]):
/// nothing was sent; [problems] say which fields.
class BillingDraftInvalid implements TypedRefusal {
  const BillingDraftInvalid(this.problems);

  final Map<String, BillingPartyProblem> problems;

  @override
  String toString() => 'BillingDraftInvalid(${problems.keys.join(', ')})';
}

/// The seller's billing customers (RPCs of 0821).
abstract class BillingCustomerRepository {
  /// The business's billing customers and the members that chose a billing
  /// identity; empty for a business that has none.
  Future<List<BillingParty>> fetch(String workspaceId);

  /// Creates a billing customer with no account; returns its subject id.
  /// [capacity] (`business` or `consumer`) needs the right to issue invoices.
  Future<String> create(
    String workspaceId,
    BillingPartyDraft draft, {
    String? capacity,
  });

  /// Edits the fields of [draft] on [subjectId], when the stored revision is
  /// still [expectedRevision].
  Future<BillingParty> save(
    String workspaceId,
    String subjectId,
    BillingPartyDraft draft, {
    required int expectedRevision,
    String? capacity,
  });
}

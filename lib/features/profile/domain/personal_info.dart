// SPDX-License-Identifier: 0BSD
//
// #886 — who a person is, for a document.
//
// A display name and a free-text address were enough to show a member
// on a plan; they are not enough to name the buyer on an invoice or to
// address a letter. This is the structured identity: the fields every
// form edits (the user's own settings, and — #887 — a member an admin
// manages until it is claimed), and the two renderings every document
// prints: the full name and the postal block. Both are computed here
// AND in SQL (`profile_full_name`, `profile_postal_block`, migration
// 0152); a test pins the two equal, because the invoice freezes the SQL
// rendering and the preview shows the Dart one.

/// One person's identity, as documents need it.
class PersonalInfo {
  const PersonalInfo({
    this.firstName = '',
    this.lastName = '',
    this.company = '',
    this.street = '',
    this.postalCode = '',
    this.city = '',
    this.countryCode = '',
    this.phone = '',
    this.email = '',
    this.vatId = '',
    this.legalId = '',
  });

  static const PersonalInfo empty = PersonalInfo();

  final String firstName;
  final String lastName;

  /// The organisation the person is invoiced through, when any — the
  /// reference sheet's "Société et/ou nom de l'adhérent".
  final String company;
  final String street;
  final String postalCode;
  final String city;

  /// ISO 3166-1 alpha-2, upper case.
  final String countryCode;
  final String phone;

  /// The billing e-mail — documents are sent here. The account's login
  /// e-mail is not this field and is never printed.
  final String email;
  final String vatId;

  /// SIRET, Handelsregister number, company number… (EN 16931 BT-47).
  final String legalId;

  /// Every field blank.
  bool get isEmpty =>
      firstName.isEmpty &&
      lastName.isEmpty &&
      company.isEmpty &&
      street.isEmpty &&
      postalCode.isEmpty &&
      city.isEmpty &&
      countryCode.isEmpty &&
      phone.isEmpty &&
      email.isEmpty &&
      vatId.isEmpty &&
      legalId.isEmpty;

  /// Enough to name AND locate the client: a name (or a company) and a
  /// street or city.
  bool get isPostalComplete =>
      fullName.isNotEmpty && (street.isNotEmpty || city.isNotEmpty);

  /// "Prénom NOM" — the family name in capitals, as French letters and
  /// most European invoices write it; either half alone when the other
  /// is missing.
  ///
  /// #910 — a client is not always a person. An admin-managed profile
  /// may hold nothing but a COMPANY (the invitation only needs one of
  /// the three), and a company is who the invoice is addressed to: with
  /// no fallback the document named nobody and every surface that
  /// interpolated the name printed an orphan separator. So the company
  /// stands in when neither half of a personal name is given, and
  /// [postalBlock] then leaves it out — it is on the line above.
  String get fullName {
    final personal = _fullName(firstName, lastName);
    return personal.isNotEmpty ? personal : company.trim();
  }

  /// The personal name alone, without the company standing in for it —
  /// what a greeting needs, and what tells [postalBlock] whether the
  /// company has been promoted to the name line.
  String get personName => _fullName(firstName, lastName);

  /// The postal block, one line per element, as the envelope window and
  /// the invoice print it:
  ///
  ///     Company                     (when any)
  ///     Street
  ///     POSTAL CITY                 (locality in capitals — NF Z 10-011)
  ///     FR                          (only when abroad, relative to
  ///                                  [workspaceCountry])
  ///
  /// The name is NOT part of the block: the recipient widget prints it
  /// on its own line above, so a company can sit between them.
  ///
  /// [nameAbove] is the line the document prints over the block —
  /// [fullName] by default. When it IS the company (a client with no
  /// personal name, #910), the company line is dropped: printing
  /// "SASU KaloA" twice, once as the addressee and again as the first
  /// line of its own address, is not an address.
  String postalBlock({String workspaceCountry = '', String? nameAbove}) =>
      _postalBlock(
        company:
            company.trim() == (nameAbove ?? fullName).trim() ? '' : company,
        street: street,
        postalCode: postalCode,
        city: city,
        countryCode: countryCode,
        workspaceCountry: workspaceCountry,
      );

  PersonalInfo copyWith({
    String? firstName,
    String? lastName,
    String? company,
    String? street,
    String? postalCode,
    String? city,
    String? countryCode,
    String? phone,
    String? email,
    String? vatId,
    String? legalId,
  }) => PersonalInfo(
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    company: company ?? this.company,
    street: street ?? this.street,
    postalCode: postalCode ?? this.postalCode,
    city: city ?? this.city,
    countryCode: countryCode ?? this.countryCode,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    vatId: vatId ?? this.vatId,
    legalId: legalId ?? this.legalId,
  );

  /// Trimmed, with the country code upper-cased — what is stored.
  PersonalInfo normalized() => PersonalInfo(
    firstName: firstName.trim(),
    lastName: lastName.trim(),
    company: company.trim(),
    street: street.trim(),
    postalCode: postalCode.trim(),
    city: city.trim(),
    countryCode: countryCode.trim().toUpperCase(),
    phone: phone.trim(),
    email: email.trim(),
    vatId: vatId.trim(),
    legalId: legalId.trim(),
  );

  /// The wire keys — the same on `profiles` columns (0152) and inside a
  /// managed member's `managed_identity` (#887), so one reader serves both.
  static const String keyFirstName = 'first_name';
  static const String keyLastName = 'last_name';
  static const String keyCompany = 'company';
  static const String keyStreet = 'street';
  static const String keyPostalCode = 'postal_code';
  static const String keyCity = 'city';
  static const String keyCountryCode = 'country_code';
  static const String keyPhone = 'phone';
  static const String keyEmail = 'email';
  static const String keyVatId = 'vat_id';
  static const String keyLegalId = 'legal_id';

  factory PersonalInfo.fromDb(Map<String, dynamic> db) => PersonalInfo(
    firstName: db[keyFirstName] as String? ?? '',
    lastName: db[keyLastName] as String? ?? '',
    company: db[keyCompany] as String? ?? '',
    street: db[keyStreet] as String? ?? '',
    postalCode: db[keyPostalCode] as String? ?? '',
    city: db[keyCity] as String? ?? '',
    countryCode: db[keyCountryCode] as String? ?? '',
    phone: db[keyPhone] as String? ?? '',
    email: db[keyEmail] as String? ?? '',
    vatId: db[keyVatId] as String? ?? '',
    legalId: db[keyLegalId] as String? ?? '',
  );

  Map<String, dynamic> toDb() => {
    keyFirstName: firstName,
    keyLastName: lastName,
    keyCompany: company,
    keyStreet: street,
    keyPostalCode: postalCode,
    keyCity: city,
    keyCountryCode: countryCode,
    keyPhone: phone,
    keyEmail: email,
    keyVatId: vatId,
    keyLegalId: legalId,
  };

  @override
  bool operator ==(Object other) =>
      other is PersonalInfo &&
      other.firstName == firstName &&
      other.lastName == lastName &&
      other.company == company &&
      other.street == street &&
      other.postalCode == postalCode &&
      other.city == city &&
      other.countryCode == countryCode &&
      other.phone == phone &&
      other.email == email &&
      other.vatId == vatId &&
      other.legalId == legalId;

  @override
  int get hashCode => Object.hash(
    firstName,
    lastName,
    company,
    street,
    postalCode,
    city,
    countryCode,
    phone,
    email,
    vatId,
    legalId,
  );
}

/// The two renderings, as plain functions so the SQL twins in migration
/// 0152 can be read side by side with them.
String _fullName(String first, String last) {
  final f = first.trim();
  final l = last.trim().toUpperCase();
  if (f.isEmpty) return l;
  if (l.isEmpty) return f;
  return '$f $l';
}

String _postalBlock({
  required String company,
  required String street,
  required String postalCode,
  required String city,
  required String countryCode,
  required String workspaceCountry,
}) {
  final locality = [
    postalCode.trim(),
    city.trim().toUpperCase(),
  ].where((p) => p.isNotEmpty).join(' ');
  final abroad =
      countryCode.trim().isNotEmpty &&
      workspaceCountry.trim().isNotEmpty &&
      countryCode.trim().toUpperCase() != workspaceCountry.trim().toUpperCase();
  return [
    company.trim(),
    street.trim(),
    locality,
    if (abroad) countryCode.trim().toUpperCase(),
  ].where((l) => l.isNotEmpty).join('\n');
}

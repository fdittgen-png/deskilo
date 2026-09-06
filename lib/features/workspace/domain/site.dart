// SPDX-License-Identifier: 0BSD
//
// #945 — a site: the unit of address. Levels belong to a site, a member
// has a home site, and a document names the site it concerns (#946).
// Every workspace has a default site carrying the address it always
// had; a null `Level.siteId` or `Member.homeSiteId` means that one.
class Site {
  const Site({
    required this.id,
    required this.workspaceId,
    required this.name,
    this.street = '',
    this.postalCode = '',
    this.city = '',
    this.countryCode = '',
    this.legalId = '',
    this.vatId = '',
    this.taxExemptionReason = '',
    this.isDefault = false,
    this.sortOrder = 0,
  });

  final String id;
  final String workspaceId;
  final String name;
  final String street;
  final String postalCode;
  final String city;

  /// ISO 3166-1 alpha-2, upper case.
  final String countryCode;

  /// The establishment's registration — a SIRET in France — under the
  /// entity's SIREN. The VAT number and the exemption stay the entity's.
  final String legalId;

  /// #948 — only for a site that is a DISTINCT legal entity: its own VAT
  /// number and exemption reason, printed on documents at that site.
  /// Empty inherits the workspace's.
  final String vatId;
  final String taxExemptionReason;
  final bool isDefault;
  final int sortOrder;

  /// Street · POSTAL CITY — one line per element, as documents print it.
  String get postalBlock => [
        street.trim(),
        [postalCode.trim(), city.trim().toUpperCase()]
            .where((p) => p.isNotEmpty)
            .join(' '),
      ].where((l) => l.isNotEmpty).join('\n');

  bool get hasAddress => street.isNotEmpty || city.isNotEmpty;

  factory Site.fromRow(Map<String, dynamic> row) => Site(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String? ?? '',
        name: row['name'] as String? ?? '',
        street: row['street'] as String? ?? '',
        postalCode: row['postal_code'] as String? ?? '',
        city: row['city'] as String? ?? '',
        countryCode: row['country_code'] as String? ?? '',
        legalId: row['legal_id'] as String? ?? '',
        vatId: row['vat_id'] as String? ?? '',
        taxExemptionReason: row['tax_exemption_reason'] as String? ?? '',
        isDefault: row['is_default'] as bool? ?? false,
        sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      );

  Site copyWith({
    String? name,
    String? street,
    String? postalCode,
    String? city,
    String? countryCode,
    String? legalId,
    String? vatId,
    String? taxExemptionReason,
    int? sortOrder,
  }) =>
      Site(
        id: id,
        workspaceId: workspaceId,
        name: name ?? this.name,
        street: street ?? this.street,
        postalCode: postalCode ?? this.postalCode,
        city: city ?? this.city,
        countryCode: countryCode ?? this.countryCode,
        legalId: legalId ?? this.legalId,
        vatId: vatId ?? this.vatId,
        taxExemptionReason: taxExemptionReason ?? this.taxExemptionReason,
        isDefault: isDefault,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}

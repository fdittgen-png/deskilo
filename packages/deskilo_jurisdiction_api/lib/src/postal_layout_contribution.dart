// SPDX-License-Identifier: AGPL-3.0-or-later
import 'capability_descriptor.dart';

/// A part of the lines an address writes below its street.
enum PostalPart { postalCode, city, region }

/// What a country calls the region of an address.
enum RegionKind { state, province, county, canton, region }

/// The region field of a country's addresses: what it is called, whether an
/// address needs one, and the codes it may hold. Data, not behaviour.
class RegionField {
  const RegionField({
    required this.kind,
    this.required = false,
    this.names = const {},
    this.printsName = false,
  });

  final RegionKind kind;

  /// An address of this country is incomplete without its region.
  final bool required;

  /// The country's regions, by code (the second part of ISO 3166-2) with the
  /// name its post prints. Empty: any code is accepted.
  final Map<String, String> names;

  /// The address prints the region's name rather than its code.
  final bool printsName;
}

/// How a country writes the lines of an address below its street: which parts
/// each line joins, in order, and which are in capitals. Data, not behaviour:
/// the host adds the name, the street and the country line.
class PostalLayout {
  const PostalLayout({
    required this.lines,
    this.cityInCapitals = false,
    this.postalCodeInCapitals = false,
    this.region,
  });

  /// The lines below the street, each the parts it joins with one space.
  final List<List<PostalPart>> lines;

  /// The locality in capitals on a mailing address (France: NF Z 10-011; the
  /// post town in the United Kingdom; the United States and Canada).
  final bool cityInCapitals;

  /// The postal code in capitals (a British postcode, an Irish Eircode, a
  /// Canadian postal code).
  final bool postalCodeInCapitals;

  /// The region field of an address, or null when the country's addresses
  /// have none.
  final RegionField? region;
}

/// The layout of a country with no layout of its own: the postal code, the
/// locality in capitals, then the region the address names.
const PostalLayout defaultPostalLayout = PostalLayout(
  lines: [
    [PostalPart.postalCode, PostalPart.city, PostalPart.region],
  ],
  cityInCapitals: true,
  region: RegionField(kind: RegionKind.region),
);

/// A country's way of writing an address. The country is the one in the
/// capability id (`postal_layout.US`); a country with none is written with
/// [defaultPostalLayout].
abstract class PostalLayoutContribution {
  const PostalLayoutContribution();

  CapabilityDescriptor get descriptor;

  PostalLayout get layout;
}

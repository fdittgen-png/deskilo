// SPDX-License-Identifier: AGPL-3.0-or-later
import 'capability_descriptor.dart';

/// A part of the lines an address writes below its street.
enum PostalPart { postalCode, city, region }

/// How a country writes the lines of an address below its street: which parts
/// each line joins, in order, and which are in capitals. Data, not behaviour:
/// the host adds the name, the street and the country line.
class PostalLayout {
  const PostalLayout({
    required this.lines,
    this.cityInCapitals = false,
    this.postalCodeInCapitals = false,
  });

  /// The lines below the street, each the parts it joins with one space.
  final List<List<PostalPart>> lines;

  /// The locality in capitals on a mailing address (France: NF Z 10-011; the
  /// post town in the United Kingdom; the United States and Canada).
  final bool cityInCapitals;

  /// The postal code in capitals (a British postcode, an Irish Eircode, a
  /// Canadian postal code).
  final bool postalCodeInCapitals;
}

/// The layout of a country with no layout of its own: the postal code, the
/// locality in capitals, then the region the address names.
const PostalLayout defaultPostalLayout = PostalLayout(
  lines: [
    [PostalPart.postalCode, PostalPart.city, PostalPart.region],
  ],
  cityInCapitals: true,
);

/// A country's way of writing an address. The country is the one in the
/// capability id (`postal_layout.US`); a country with none is written with
/// [defaultPostalLayout].
abstract class PostalLayoutContribution {
  const PostalLayoutContribution();

  CapabilityDescriptor get descriptor;

  PostalLayout get layout;
}

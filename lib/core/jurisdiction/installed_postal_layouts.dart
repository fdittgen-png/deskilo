// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3649 -- the postal layouts this build installs: a static list, compiled in,
// like the other capabilities. A country not listed is written with the
// default layout.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_ca/deskilo_jurisdiction_ca.dart';
import 'package:deskilo_jurisdiction_ch/deskilo_jurisdiction_ch.dart';
import 'package:deskilo_jurisdiction_de/deskilo_jurisdiction_de.dart';
import 'package:deskilo_jurisdiction_es/deskilo_jurisdiction_es.dart';
import 'package:deskilo_jurisdiction_fr/deskilo_jurisdiction_fr.dart';
import 'package:deskilo_jurisdiction_gb/deskilo_jurisdiction_gb.dart';
import 'package:deskilo_jurisdiction_ie/deskilo_jurisdiction_ie.dart';
import 'package:deskilo_jurisdiction_it/deskilo_jurisdiction_it.dart';
import 'package:deskilo_jurisdiction_pl/deskilo_jurisdiction_pl.dart';
import 'package:deskilo_jurisdiction_us/deskilo_jurisdiction_us.dart';
import 'package:meta/meta.dart';

import 'jurisdiction_resolver.dart';

/// Every installed postal layout.
@visibleForTesting
const List<PostalLayoutContribution> installedPostalLayouts = [
  CaPostalLayout(),
  ChPostalLayout(),
  DePostalLayout(),
  EsPostalLayout(),
  FrPostalLayout(),
  GbPostalLayout(),
  IePostalLayout(),
  ItPostalLayout(),
  PlPostalLayout(),
  UsPostalLayout(),
];

/// How an address in [country] is written below its street.
PostalLayout postalLayoutOf(String country) =>
    resolvePostalLayout(
      LegalContext(countryCode: country),
      installedPostalLayouts,
    )?.layout ??
    defaultPostalLayout;

/// How the host writes a [PostalLayout]: the contract is data, the writing is
/// the application's.
extension PostalLines on PostalLayout {
  /// The lines of one address. [capitals] false writes the parts as given:
  /// an address inside a sentence or on one line is not a mailing address. A
  /// part left blank drops out, and so does a line with nothing left.
  List<String> render({
    required String postalCode,
    required String city,
    String region = '',
    bool capitals = true,
  }) {
    String part(PostalPart p) => switch (p) {
      PostalPart.postalCode => _cased(
        postalCode,
        capitals && postalCodeInCapitals,
      ),
      PostalPart.city => _cased(city, capitals && cityInCapitals),
      PostalPart.region => regionText(region),
    };
    return [
      for (final line in lines)
        line.map(part).where((p) => p.isNotEmpty).join(' '),
    ].where((l) => l.isNotEmpty).toList();
  }
}

/// Helpers for the region field of a layout: one place says how a region is
/// stored and whether an address of a country may hold it.
extension RegionOfLayout on PostalLayout {
  /// What the address prints for the region [code]: its name where the
  /// country's post prints names, else the code.
  String regionText(String code) {
    final c = regionCode(code);
    final field = region;
    if (field == null || !field.printsName) return c;
    return field.names[c] ?? c;
  }

  /// Why [code] cannot be the region of an address in this country, or null.
  RegionRefusal? regionRefusal(String code) {
    final c = regionCode(code);
    final field = region;
    if (c.isEmpty) {
      return field != null && field.required ? RegionRefusal.missing : null;
    }
    if (!_regionShape.hasMatch(c)) return RegionRefusal.notACode;
    if (field == null) return null;
    if (field.names.isNotEmpty && !field.names.containsKey(c)) {
      return RegionRefusal.unknown;
    }
    return null;
  }
}

/// Why a region cannot be stored.
enum RegionRefusal { missing, notACode, unknown }

/// A region as it is stored: its code, trimmed and in upper case -- what both
/// editors of an address write.
String regionCode(String input) => input.trim().toUpperCase();

/// The shape the database holds (`subdivision_code`, 0785).
final RegExp _regionShape = RegExp(r'^[A-Z0-9-]{1,10}$');

String _cased(String value, bool upper) =>
    upper ? value.trim().toUpperCase() : value.trim();

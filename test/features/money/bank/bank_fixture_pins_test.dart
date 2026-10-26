// SPDX-License-Identifier: AGPL-3.0-or-later
// test-inventory: pure rules — the invariant is the fixture bytes
//
// #2380 — every bank statement fixture is pinned by its sha256: a published
// sample is kept byte for byte as its publisher ships it, and a synthetic one
// (built from the format's specification where no sample is published, or
// none can be fetched) cannot drift under the tests that read it. The
// manifest names where each comes from; a fixture the manifest does not name
// fails, so nothing enters the folder unaccounted for.
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

const _dir = 'test/features/money/fixtures/bank';

/// The specification a synthetic fixture is built from.
const _synthetic = 'synthetic';

/// file → (sha256, source, publisher).
const Map<String, (String, String, String)> _manifest = {
  // Published: SIX Interbank Clearing, "XML examples CH interbank 2026",
  // ig-xml-examples-ch-interbank-2026-en.zip (zip sha256
  // e83e3722302d192c64533bec6337ee53e018374eea9bb50aa1cdd408bbc04e31),
  // member 01_RTGS_Services/RTGS_camt_054_sample.xml, unchanged.
  'six_rtgs_camt_054_sample.xml': (
    'bde57d30a3d2b8d46b35a90f4fa081f3d61740e29f0a6687908b7f4d76ffdb10',
    'https://www.six-group.com/dam/download/banking-services/standardization/sic-eurosic/5-3/ig-xml-examples-ch-interbank-2026-en.zip',
    'SIX Interbank Clearing',
  ),
  // The Swiss Payment Standards cash-management examples (camt.053 for
  // customers) are not published as files on the SIX download page (only
  // the PDF guide); ISO 20022 (iso20022.org) answers 403 to a download.
  'camt053_statement.xml': (
    '6af6006f1894d09a78f5cd8deb90fbed3d937346f3ff8836c5c7255aea3b68cc',
    'ISO 20022 camt.053.001.08 message definition; SIX ig-cash-management-sps-2026-en.pdf',
    _synthetic,
  ),
  'camt054_notification.xml': (
    'e38ac303c7d06c856d5ac98ede54c6a80d56b7021c78a5b0a55a8e93cb170d82',
    'ISO 20022 camt.054.001.08 message definition',
    _synthetic,
  ),
  // SWIFT publishes MT940 behind its member portal; no bank sample file is
  // published under a reusable licence.
  'mt940_statement.sta': (
    '5e690b5b9ee326201745230fc7e5988bd7a4c310147c70559a0bd3f1148d446d',
    'SWIFT MT940 field specification; DFÜ-Abkommen Anlage 3 (:86: ?-subfields)',
    _synthetic,
  ),
  // Febelfin's CODA page (febelfin.be/en/coda) answers 404; the standard is
  // the CODA 2.6 record description.
  'coda_statement.cod': (
    '0b328f69d54fd8fee74c6107d18521a6b83f3573ade320d0ff83f65cfdb6ce8c',
    'Febelfin CODA 2.6 record description',
    _synthetic,
  ),
  // ofx.net is a parked domain; financialdataexchange.org answers 403.
  'ofx_statement.ofx': (
    '7ce58d02548a32bc8ebcf87bdd80f41f9a400efa8fe331523ae60ec4fd29828a',
    'OFX 1.0.2 specification (SGML)',
    _synthetic,
  ),
  'ofx2_statement.ofx': (
    '800e1053bdb101a79adec6a6b178caad1d62a677bfe997095d4e225c1aebff6f',
    'OFX 2.2 specification (XML)',
    _synthetic,
  ),
  'csv_statement.csv': (
    'facc6a80be09f4b92a22f808e475c055c3beb400c51afa5fad5dc66adf77afd1',
    'RFC 4180, with a German bank export layout',
    _synthetic,
  ),
};

void main() {
  test('every fixture is the one the manifest pins', () {
    final files = Directory(_dir)
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toSet();
    expect(files, _manifest.keys.toSet());
    for (final MapEntry(key: name, value: (sha, _, _)) in _manifest.entries) {
      final digest = sha256.convert(File('$_dir/$name').readAsBytesSync());
      expect('$digest', sha, reason: name);
    }
  });

  test('a published fixture names its download', () {
    for (final (_, source, publisher) in _manifest.values) {
      if (publisher != _synthetic) expect(source, startsWith('https://'));
    }
  });
}

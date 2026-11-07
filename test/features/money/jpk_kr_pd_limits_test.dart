// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3380 — each named JPK_KR_PD length is the one the pinned schema fixes. The
// numbers are read from the XSD under test/fixtures; a constant that differs
// from the schema is red.
import 'dart:io';

import 'package:deskilo/features/money/domain/jpk_kr_pd_limits.dart';
import 'package:flutter_test/flutter_test.dart';

const _dir = 'test/fixtures/saft/jpk_kr_pl';

String _read(String file) => File('$_dir/$file').readAsStringSync();

/// The maxLength of the simple type [name] (or the element, for an inline
/// type) in [file].
int _maxLength(String file, String name, {bool element = false}) {
  final text = _read(file);
  final start = text.indexOf(
    element ? 'element name="$name"' : 'simpleType name="$name"',
  );
  expect(start, isNonNegative, reason: '$name is not in $file');
  final end = text.indexOf(
    element ? '</xsd:element>' : '</xsd:simpleType>',
    start,
  );
  final m = RegExp(r'maxLength value="(\d+)"')
      .firstMatch(text.substring(start, end));
  expect(m, isNotNull, reason: '$name has no maxLength');
  return int.parse(m!.group(1)!);
}

void main() {
  const etd = 'ElementarneTypyDanych_v10-0E.xsd';
  const jpk = 'JPK_KR_PD_1_v1-1.xsd';
  final pins = <String, (int, int Function())>{
    'legal name: Podmiot1/PelnaNazwa': (
      jpkKrPdLegalNameLength,
      () =>
          _maxLength('StrukturyDanych_v10-0E.xsd', 'PelnaNazwa', element: true),
    ),
    'TJednAdmin': (jpkKrPdAdminUnitLength, () => _maxLength(etd, 'TJednAdmin')),
    'TUlica': (jpkKrPdStreetLength, () => _maxLength(etd, 'TUlica')),
    'TNrBudynku': (
      jpkKrPdBuildingNumberLength,
      () => _maxLength(etd, 'TNrBudynku'),
    ),
    'TMiejscowosc': (jpkKrPdCityLength, () => _maxLength(etd, 'TMiejscowosc')),
    'TKodPocztowy': (
      jpkKrPdPostalCodeLength,
      () => _maxLength(etd, 'TKodPocztowy'),
    ),
    'TZnakowyJPK': (jpkKrPdTextLength, () => _maxLength(jpk, 'TZnakowyJPK')),
    'TZnakowy512': (
      jpkKrPdLongTextLength,
      () => _maxLength(jpk, 'TZnakowy512'),
    ),
    'TNrIdentyfikacjiPodatkowej': (
      jpkKrPdTaxIdLength,
      () => _maxLength(etd, 'TNrIdentyfikacjiPodatkowej'),
    ),
  };
  for (final MapEntry(key: name, value: (constant, schema)) in pins.entries) {
    test('$name: the constant is the schema length', () {
      expect(constant, schema());
    });
  }

  test('TKwotowy: the amount precision is the schema totalDigits', () {
    final text = _read(jpk);
    final start = text.indexOf('simpleType name="TKwotowy"');
    final end = text.indexOf('</xsd:simpleType>', start);
    final m = RegExp(r'totalDigits value="(\d+)"')
        .firstMatch(text.substring(start, end));
    expect(jpkKrPdAmountDigits, int.parse(m!.group(1)!));
  });
}

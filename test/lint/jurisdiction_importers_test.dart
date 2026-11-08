// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the application reaches a country's add-on through the
// contract and the installed compositions (`installed_*.dart`), never by
// importing `deskilo_jurisdiction_<country>` itself: a generic file that names
// one country's package is a file the removability proof cannot cross.
//
// RATCHET over comment-free source, matched on the whole joined code (a URI
// split over lines, a conditional import, a country added tomorrow all count;
// only the contract and the standards packages are exempt): the files outside
// the composition that still import a country add-on may only fall. Today's
// three are checklist items of #3429 (the GB MTD boxes, the Italian stamp duty
// and register).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The files that still import a country add-on, each with its item.
const _importers = <String, String>{
  'lib/features/money/domain/mtd_boxes.dart': '#3429 presentation / filing: GB MTD',
  'lib/features/money/domain/stamp_duty.dart': '#3429 invoice validity: IT stamp duty',
  'lib/features/money/domain/vat_register_it.dart': '#3429 VAT registers: IT',
};

/// Any country add-on package, in any import or export, wherever its URI sits.
final _countryAddOn = RegExp(
  r'''package:deskilo_jurisdiction_(?!api\b|standards\b)\w+/''',
);

/// The code of [path] with comments dropped, on one line.
String _codeOf(String path) => File(path)
    .readAsLinesSync()
    .where((l) => l.trim().isNotEmpty && !l.trimLeft().startsWith('//'))
    .map((l) => l.trim())
    .join(' ');

void main() {
  test('the matcher sees a new country, a split URI and a conditional URI, '
      'and not the contract or the standards', () {
    expect(_countryAddOn.hasMatch("import 'package:deskilo_jurisdiction_xx/a.dart';"), isTrue);
    expect(
      _countryAddOn.hasMatch(
        "import\n 'package:deskilo_jurisdiction_it/\n deskilo_jurisdiction_it.dart';"
            .replaceAll('\n', ' '),
      ),
      isTrue,
    );
    expect(
      _countryAddOn.hasMatch(
        "import 'a_stub.dart' if (dart.library.io) "
        "'package:deskilo_jurisdiction_pl/a.dart';",
      ),
      isTrue,
    );
    expect(_countryAddOn.hasMatch("import 'package:deskilo_jurisdiction_api/x.dart';"), isFalse);
    expect(_countryAddOn.hasMatch("import 'package:deskilo_jurisdiction_standards/x.dart';"), isFalse);
    expect(_countryAddOn.hasMatch("import 'package:deskilo_jurisdiction_apix/x.dart';"), isTrue);
  });

  test('only the compositions import a country add-on; the rest only falls', () {
    final found = <String>{
      for (final f in handWrittenDartFiles('lib'))
        if (!f.uri.pathSegments.last.startsWith('installed_') &&
            _countryAddOn.hasMatch(_codeOf(f.path)))
          f.path.replaceFirst(RegExp(r'^.*?(?=lib/)'), ''),
    };
    expect(
      found.difference(_importers.keys.toSet()),
      isEmpty,
      reason:
          'a generic file asks the resolver; a country package is imported '
          'by an installed_*.dart composition only',
    );
    expect(
      _importers.keys.toSet().difference(found),
      isEmpty,
      reason: 'progress: delete the entries that no longer import one',
    );
  });
}

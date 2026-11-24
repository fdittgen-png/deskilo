// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4413 -- two counts that only fall, per area (a feature, a folder of core, a
// package's library):
//  - exception classes that are not the app's failure: a class that implements
//    or extends an `...Exception` type instead of being an `AppFailure` or a
//    `TypedRefusal` (lib/core/failure/app_failure.dart). A typed refusal of a
//    feature implements `TypedRefusal`; anything else becomes one as its
//    commands move onto `CommandOutcome`.
//  - the SDK's exception types caught by name (`on PostgrestException`, ...):
//    the data layer converts them once with `appFailureFrom`; each catch by
//    name that goes away lowers its area.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

final _exceptionClass = RegExp(
  r'\bclass\s+\w+[^{;]*?\b(?:implements|extends)\b[^{;]*?\b\w*Exception\b[^{;]*\{',
);
final _sdkCatch = RegExp(
  r'\bon\s+(?:PostgrestException|AuthException|AuthRetryableFetchException|'
  r'FunctionException|FunctionsException|StorageException)\b',
);

/// The area a file is counted under.
String areaOf(String path) {
  final p = path.replaceAll(r'\', '/');
  final package = RegExp(r'packages/(\w+)/lib/').firstMatch(p);
  if (package != null) return 'packages/${package.group(1)}';
  final feature = RegExp(r'lib/features/(\w+)/').firstMatch(p);
  if (feature != null) return 'features/${feature.group(1)}';
  final core = RegExp(r'lib/core/(\w+)/').firstMatch(p);
  return core == null ? 'lib' : 'core/${core.group(1)}';
}

/// Code lines of [source]: line comments dropped.
String _code(String source) =>
    source.split('\n').where((l) => !l.trimLeft().startsWith('//')).join('\n');

int exceptionClasses(String source) =>
    _exceptionClass.allMatches(_code(source)).length;

int sdkCatches(String source) => _sdkCatch.allMatches(_code(source)).length;

/// Measured on 24 Nov 2026 (#4413). Only falls.
const _exceptionClassCeiling = <String, int>{
  'core/backend': 10,
  'core/cache': 1,
  'core/data': 2,
  'core/demo': 1,
  'core/files': 1,
  'core/i18n': 1,
  'core/images': 2,
  'core/instance': 4,
  'core/public_network': 2,
  'core/settings': 3,
  'core/time': 1,
  'core/trace': 1,
  'core/validation': 1,
  'features/auth': 1,
  'features/directory': 2,
  'features/mcp': 4,
  'features/me': 7,
  'features/money': 26,
  'features/profile': 1,
  'features/reservations': 7,
  'features/stock': 2,
  'features/task_recorder': 8,
  'features/workspace': 19,
  'lib': 1,
  'packages/deskilo_document_model': 1,
  'packages/deskilo_invoice_model': 2,
  'packages/deskilo_jurisdiction_api': 1,
  'packages/deskilo_jurisdiction_ch': 1,
  'packages/deskilo_jurisdiction_es': 1,
  'packages/deskilo_jurisdiction_it': 1,
  'packages/deskilo_money_kernel': 3,
  'packages/deskilo_tax_reference': 1,
};

/// Measured on 24 Nov 2026 (#4413). Only falls.
const _sdkCatchCeiling = <String, int>{
  'core/backend': 9,
  'core/public_network': 1,
  'features/auth': 6,
  'features/directory': 3,
  'features/editor': 1,
  'features/mcp': 4,
  'features/me': 4,
  'features/money': 34,
  'features/profile': 2,
  'features/reservations': 3,
  'features/stock': 1,
  'features/workspace': 29,
};

Map<String, int> _measure(
  int Function(String) count, {
  bool skipFailureRoot = false,
}) {
  final out = <String, int>{};
  final files = [
    ...handWrittenDartFiles('lib'),
    for (final package in directoryNames('packages'))
      if (directoryAt('packages/$package/lib').existsSync())
        ...handWrittenDartFiles('packages/$package/lib'),
  ];
  for (final f in files) {
    // The failure root itself (AppFailure, TypedRefusal) is the type the
    // others become.
    if (skipFailureRoot &&
        f.path.replaceAll(r'\', '/').contains('lib/core/failure/')) {
      continue;
    }
    final n = count(f.readAsStringSync());
    if (n > 0) out.update(areaOf(f.path), (v) => v + n, ifAbsent: () => n);
  }
  return out;
}

List<String> _changed(Map<String, int> actual, Map<String, int> ceiling) => [
  for (final area in {...actual.keys, ...ceiling.keys}.toList()..sort())
    if ((actual[area] ?? 0) != (ceiling[area] ?? 0))
      '$area: ${actual[area] ?? 0} (ceiling ${ceiling[area] ?? 0})',
];

void main() {
  test('the detectors, on planted text', () {
    expect(
      exceptionClasses(
        'class A implements Exception {}\n'
        'final class B extends StateException {}\n'
        'class C implements TypedRefusal {}\n'
        'final class D extends AppFailure {}\n'
        '// class E implements Exception {}\n',
      ),
      2,
    );
    expect(
      sdkCatches(
        '} on PostgrestException catch (e, st) {\n'
        '} on StorageException {\n'
        '} on FormatException catch (e, st) {\n',
      ),
      2,
    );
    expect(areaOf('lib/features/money/data/x.dart'), 'features/money');
    expect(
      areaOf('packages/deskilo_xlsx/lib/src/x.dart'),
      'packages/deskilo_xlsx',
    );
  });

  test('exception classes that are not the app failure only fall', () {
    final actual = _measure(exceptionClasses, skipFailureRoot: true);
    expect(
      _changed(actual, _exceptionClassCeiling),
      isEmpty,
      reason:
          'make a new failure an AppFailure or a TypedRefusal; when one '
          'left, lower its area.\n$actual',
    );
  });

  test('the SDK exception types caught by name only fall', () {
    final actual = _measure(sdkCatches);
    expect(
      _changed(actual, _sdkCatchCeiling),
      isEmpty,
      reason:
          'convert with appFailureFrom in the data layer and catch the '
          'AppFailure; when one left, lower its area.\n$actual',
    );
  });
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4413 -- the SDK's exception types are named in a data layer only (`lib/core/data`, `lib/core/*/data`, which
// holds the Demo's stand-ins for the server, and `lib/features/*/data`). Everywhere else a failure is an
// `AppFailure` (lib/core/failure/app_failure.dart), converted once by `appFailureFrom`. The files that still
// name an SDK type outside a data layer are counted per layer; a count only falls (presentation first, to 0).
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

final _sdkType = RegExp(
  r'\b(PostgrestException|AuthException|AuthRetryableFetchException|FunctionException|FunctionsException|StorageException)\b',
);
final _dataLayer = RegExp(r'^lib/(core|core/[a-z_]+|features/[a-z_]+)/data/');

/// The layer a file outside a data layer belongs to, for its ceiling.
String layerOf(String path) {
  if (path.contains('/presentation/')) return 'presentation';
  if (path.contains('/application/')) return 'application';
  if (path.contains('/domain/')) return 'domain';
  final core = RegExp(r'^lib/core/([a-z_]+)/').firstMatch(path);
  return core == null ? 'other' : 'core/${core.group(1)}';
}

/// [path] names an SDK exception type outside a data layer.
bool namesSdkOutsideData(String path, String source) =>
    !_dataLayer.hasMatch(path) && _sdkType.hasMatch(source);

/// Files per layer that name an SDK type outside a data layer, measured on 23 Nov 2026. Only falls.
const _ceilings = {
  'presentation': 5,
  'core/backend': 7,
  'core/trace': 1,
};

void main() {
  test('the SDK exception types are named in data layers only, or within the falling ceilings', () {
    final found = <String, List<String>>{};
    for (final f in handWrittenDartFiles('lib')) {
      final path = f.path.replaceAll(r'\', '/');
      if (namesSdkOutsideData(path, f.readAsStringSync())) {
        found.putIfAbsent(layerOf(path), () => []).add(path);
      }
    }
    for (final layer in {...found.keys, ..._ceilings.keys}) {
      final files = found[layer] ?? const [];
      final ceiling = _ceilings[layer] ?? 0;
      expect(files.length, lessThanOrEqualTo(ceiling),
          reason: '$layer names an SDK exception type outside a data layer: convert it with appFailureFrom in data/ '
              'and read an AppFailure above it (#4413):\n${files.join('\n')}');
      if (files.length < ceiling) fail('lower the $layer ceiling to ${files.length} (#4413)');
    }
  });

  test('the rule sees a presentation file that catches the SDK type, and lets a data file do it', () {
    const catching = "try { await save(); } on PostgrestException catch (e) { show(e.message); }";
    expect(namesSdkOutsideData('lib/features/money/presentation/x_screen.dart', catching), isTrue);
    expect(layerOf('lib/features/money/presentation/x_screen.dart'), 'presentation');
    expect(namesSdkOutsideData('lib/features/money/data/x_repository.dart', catching), isFalse);
    expect(namesSdkOutsideData('lib/core/demo/data/fake.dart', catching), isFalse);
    expect(namesSdkOutsideData('lib/features/money/presentation/y.dart', 'final failure = appFailureFrom(e);'), isFalse);
  });
}

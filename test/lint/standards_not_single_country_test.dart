// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3337 -- the standards package holds what SEVERAL countries share. A table
// or rule only one country reads belongs in that country's add-on; parked in
// standards it makes the add-on look removable while the application still
// depends on it. Every source file of the package must have a declaration that
// at least two jurisdiction packages use.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

const _standards = 'packages/deskilo_jurisdiction_standards';

/// A file here may stay with one jurisdiction package: it is generic, not a
/// country's table. A new entry is a reviewed claim, which is the point.
const _allowed = <String, String>{
  'csv.dart': 'CSV cell escaping with injection defence: generic, not a table',
};

final _typeDecl = RegExp(
  r'^(?:abstract |sealed |final |base )*(?:class|enum|typedef|mixin|extension type) (\w+)',
);
final _valueDecl = RegExp(r'^(?:const|final) (?:[\w<>?,]+ )?(\w+) =');
final _functionDecl = RegExp(r'(\w+)\s*(?:<[^>]*>)?\s*\(');

/// The public top-level names a standards source declares.
Set<String> _declared(String source) {
  final names = <String>{};
  for (final line in source.split('\n')) {
    if (line.isEmpty || RegExp(r'^[\s/})\]]').hasMatch(line)) continue;
    if (RegExp(r'^(import|export|library|part)\b').hasMatch(line)) continue;
    final name =
        _typeDecl.firstMatch(line)?.group(1) ??
        _valueDecl.firstMatch(line)?.group(1) ??
        _functionDecl.firstMatch(line)?.group(1);
    if (name != null && !name.startsWith('_')) names.add(name);
  }
  return names;
}

void main() {
  test(
    'every standards file is used by at least two jurisdiction packages',
    () {
      final countries = directoryNames('packages')
          .where(
            (n) =>
                n.startsWith('deskilo_jurisdiction_') &&
                n != 'deskilo_jurisdiction_api' &&
                n != 'deskilo_jurisdiction_standards',
          )
          .toList();
      final sources = {
        for (final c in countries)
          c: [
            for (final f in filesWithExtension(
              'packages/$c/lib',
              '.dart',
              recursive: true,
            ))
              f.readAsStringSync(),
          ].join('\n'),
      };
      final single = <String>[];
      for (final f in filesWithExtension(
        '$_standards/lib/src',
        '.dart',
        recursive: true,
      )) {
        final name = f.uri.pathSegments.last;
        if (_allowed.containsKey(name)) continue;
        final symbols = _declared(f.readAsStringSync());
        final users = {
          for (final e in sources.entries)
            if (symbols.any((s) => RegExp('\\b$s\\b').hasMatch(e.value))) e.key,
        };
        if (users.length < 2) single.add('$name: ${users.join(', ')}');
      }
      expect(
        single,
        isEmpty,
        reason:
            'a table only one country reads belongs in that country\'s add-on '
            '(the host may import it from there):\n${single.join('\n')}',
      );
    },
  );
}

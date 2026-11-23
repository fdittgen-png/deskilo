// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4417 -- a refusal code is spelled once. A DK code of the server is `DkCode.x` (generated
// from the migrations, lib/core/codes/dk_code.dart); a standard Postgres or PostgREST code the
// app reacts to is `PgCode.x` (lib/core/codes/pg_code.dart). A quoted code anywhere else in
// `lib/` is a typing error the app would fail to recognise at run time. The budget only falls.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

final _quotedCode = RegExp(
  r"'(DK[A-Z0-9]{3}|P0001|PGRST\d+|42501|22023|40001|42883|42703|0A000|23505|28000)'",
);

const _constantFiles = {
  'lib/core/codes/dk_code.dart',
  'lib/core/codes/pg_code.dart',
};

/// RATCHET: the quoted codes left outside the two constants files. Only falls.
const _budget = 0;

/// The quoted codes of [source]: comment lines and what follows a trailing `//` are not code.
List<String> quotedCodes(String source) => [
  for (final line in source.split('\n'))
    if (!line.trimLeft().startsWith('//') && !line.trimLeft().startsWith('*'))
      ..._quotedCode.allMatches(line.split(' //').first).map((m) => m.group(1)!),
];

void main() {
  test('a quoted code is found in code, not in a comment', () {
    expect(quotedCodes("if (e.code == '42501') {}"), ['42501']);
    expect(quotedCodes("case 'DKN01':"), ['DKN01']);
    expect(quotedCodes("// '42501' is the permission code"), isEmpty);
    expect(quotedCodes("final x = 1; // 'DKG07' later"), isEmpty);
    expect(quotedCodes("final zip = '34120';"), isEmpty);
  });

  test('no refusal code is spelled outside the constants files', () {
    final found = <String>[];
    for (final f in handWrittenDartFiles('lib')) {
      final path = f.path.replaceAll('\\', '/');
      if (_constantFiles.contains(path)) continue;
      for (final code in quotedCodes(f.readAsStringSync())) {
        found.add('$path: $code');
      }
    }
    expect(
      found.length,
      lessThanOrEqualTo(_budget),
      reason:
          'write DkCode.x / PgCode.x (#4417); a standard code the app newly '
          'reacts to joins pg_code.dart:\n${found.take(30).join('\n')}',
    );
    expect(
      found.length,
      _budget,
      reason: 'it fell: lower _budget to ${found.length}',
    );
  });
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3679 -- a kit action button in the money and the me features is given an
// async callback through the kit, never `onPressed: () { unawaited(...) }`:
// that shape is exactly the one that stays enabled while the action runs.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

void main() {
  test('no kit action button is fed through unawaited (#3679)', () {
    final shape = RegExp(
      r'KitActionButton\([^;]*?onPressed:\s*\(\)\s*\{[^}]*unawaited\(',
      dotAll: true,
    );
    final offenders = <String>[];
    for (final f in handWrittenDartFilesIn([
      'lib/features/money',
      'lib/features/me',
    ])) {
      if (shape.hasMatch(f.readAsStringSync())) offenders.add(f.path);
    }
    expect(offenders, isEmpty,
        reason: 'pass the async callback itself so the kit holds the button '
            'busy until it completes:\n${offenders.join('\n')}');
  });

  test('the lint can fail: the planted shape is found', () {
    const planted = '''
KitActionButton(label: 'x', onPressed: () {
  unawaited(save());
})''';
    expect(
      RegExp(r'KitActionButton\([^;]*?onPressed:\s*\(\)\s*\{[^}]*unawaited\(',
              dotAll: true)
          .hasMatch(planted),
      isTrue,
    );
  });
}

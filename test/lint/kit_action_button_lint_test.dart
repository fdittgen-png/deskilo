// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3679 -- a kit action button in the money and the me features is given an
// async callback through the kit, never `onPressed: () { unawaited(...) }`:
// that shape is exactly the one that stays enabled while the action runs.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

final _shape = RegExp(
  r'KitActionButton\([^;]*?onPressed:\s*\(\)\s*(\{[^}]*unawaited\(|=>\s*unawaited\()',
  dotAll: true,
);

void main() {
  test('no kit action button is fed through unawaited (#3679)', () {
    final offenders = <String>[];
    for (final f in handWrittenDartFilesIn([
      'lib/features/money',
      'lib/features/me',
    ])) {
      if (_shape.hasMatch(f.readAsStringSync())) offenders.add(f.path);
    }
    expect(offenders, isEmpty,
        reason: 'pass the async callback itself so the kit holds the button '
            'busy until it completes:\n${offenders.join('\n')}');
  });

  test('the lint can fail: both planted shapes are found', () {
    const block = '''
KitActionButton(label: 'x', onPressed: () {
  unawaited(save());
})''';
    const arrow = "KitActionButton(label: 'x', onPressed: () => unawaited(save()))";
    const fine = "KitActionButton(label: 'x', onPressed: save)";
    expect(_shape.hasMatch(block), isTrue);
    expect(_shape.hasMatch(arrow), isTrue);
    expect(_shape.hasMatch(fine), isFalse);
  });
}

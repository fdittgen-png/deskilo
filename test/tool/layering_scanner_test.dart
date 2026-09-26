// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 A2 — one scanner for the document and the lint, insensitive to
// formatting and blind to comments and string examples.
import 'package:flutter_test/flutter_test.dart';

import '../../tool/layering/analysis.dart';

bool _reads(String source) => repositoryUse.hasMatch(withoutComments(source));

void main() {
  test('a one-line access counts', () {
    expect(_reads('ref.read(moneyRepositoryProvider).x();'), isTrue);
    expect(_reads('ref.watch(moneyRepositoryProvider)'), isTrue);
  });

  test('the formatter\'s multiline shapes count the same', () {
    expect(_reads('await ref\n    .read(moneyRepositoryProvider)\n    .x();'), isTrue);
    expect(_reads('ref.read(\n  workspaceRepositoryProvider,\n)'), isTrue);
    expect(_reads('ref .watch ( fooRepositoryProvider )'), isTrue);
  });

  test('comments and strings that quote an access do not count', () {
    expect(_reads('// ref.read(moneyRepositoryProvider)'), isFalse);
    expect(_reads('/* ref\n .read(moneyRepositoryProvider) */ x();'), isFalse);
    expect(_reads("final example = 'ref.read(moneyRepositoryProvider)';"), isFalse);
    expect(_reads('final s = """\nref.read(moneyRepositoryProvider)\n""";'), isFalse);
    expect(_reads("final url = 'https://x'; ref.read(aRepositoryProvider);"), isTrue,
        reason: 'a // inside a string is not a comment');
  });

  test('a command provider or a longer name is not a repository read', () {
    expect(_reads('ref.read(expensesProvider)'), isFalse);
    expect(_reads('ref.read(moneyRepositoryProviderX)'), isFalse);
    expect(_reads('myref.read(moneyRepositoryProvider)'), isFalse);
  });
}

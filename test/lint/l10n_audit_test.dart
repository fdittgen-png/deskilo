// SPDX-License-Identifier: 0BSD
//
// #1365 — no user-facing literal outside the ones somebody decided on.
//
// `no_hardcoded_strings_test` pins one shape, `Text('literal')`. This
// reads every position where a string becomes something a member sees —
// labels, hints, helpers, errors, tooltips, semantics labels, titles,
// subtitles, snacks — and requires each literal found there to belong to
// a file whose reason is written down in `classifiedLiterals`.
//
// It is a ratchet with a reason attached, not an amnesty list: a new
// literal anywhere else fails, and a new one inside a classified file
// fails too until its count is raised deliberately.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/l10n_audit.dart';
import '../../tool/l10n_audit/audit.dart';

void main() {
  late List<Finding> findings;

  setUpAll(() => findings = auditTree(['lib']));

  test('every user-facing literal is in a file with a written reason', () {
    final unclassified = [
      for (final f in findings)
        if (!classifiedLiterals.containsKey(f.path))
          '${f.path}:${f.line} (${f.position}) "${f.literal}"',
    ];
    expect(
      unclassified,
      isEmpty,
      reason: 'a string a member will read is not going through '
          'AppLocalizations. Add the key to an ARB fragment (HARD RULE #1), '
          'or — if it is a statutory name, a proper noun or a token that '
          'must not be translated — add the file to classifiedLiterals in '
          'tool/l10n_audit/audit.dart with the reason.\n'
          '${unclassified.join('\n')}',
    );
  });

  test('each classified file holds exactly the count its reason covers', () {
    final counted = <String, int>{};
    for (final f in findings) {
      counted[f.path] = (counted[f.path] ?? 0) + 1;
    }
    final wrong = [
      for (final e in classifiedLiterals.entries)
        if ((counted[e.key] ?? 0) != e.value.allowed)
          '${e.key}: ${counted[e.key] ?? 0} found, ${e.value.allowed} '
              'written down',
    ];
    expect(wrong, isEmpty,
        reason: 'the ratchet moved. Fewer: lower the number. More: say why '
            'the new ones belong to the same class, or localize them.\n'
            '${wrong.join('\n')}');
    expect(
      classifiedLiterals.values.every((v) => v.reason.trim().length > 40),
      isTrue,
      reason: 'a class with no real reason is an amnesty, not a decision',
    );
  });

  test('docs/testing/L10N_AUDIT.md is what the tool produces today', () {
    expect(
      File(output).readAsStringSync(),
      buildAudit(),
      reason: 'the audit drifted — run `dart run tool/l10n_audit.dart` and '
          'commit the result',
    );
  });

  test('the scanner sees what it claims to see, and not what it must not',
      () {
    // Red-proof: a checker that finds nothing because it reads nothing
    // would pass every test above.
    const caught = '''
Widget build(BuildContext context) => Column(children: [
  const Text('Nothing here is translated'),
  TextField(decoration: InputDecoration(labelText: 'Your name here')),
  Tooltip(message: 'Delete this booking', child: Icon(Icons.delete)),
  IconButton(tooltip: 'Add a member', onPressed: null, icon: Icon(Icons.add)),
  Semantics(label: 'Seat map of the ground floor', child: SizedBox()),
]);
''';
    final found = auditSource('lib/x.dart', caught);
    expect(found.map((f) => f.literal).toList(), [
      'Nothing here is translated',
      'Your name here',
      'Delete this booking',
      'Add a member',
      'Seat map of the ground floor',
    ]);

    const allowed = '''
Widget build(BuildContext context) => Column(children: [
  Text(l10n?.helloThere ?? 'Hello there'),
  Text(
    l10n?.onTheNextLine ??
        'A fallback that wrapped is still a fallback',
  ),
  TextField(decoration: InputDecoration(labelText: l10n?.name ?? 'Name')),
  Text('\$stateLabel · \$count'),
  Text('{{ member }}'),
  Text('reserve.title'),
  // Text('a comment is not a violation of the rule it explains'),
  Text('assets/help/en.md'),
  Semantics(identifier: 'seat-4', child: SizedBox()),
]);
''';
    expect(auditSource('lib/y.dart', allowed), isEmpty);
  });
}

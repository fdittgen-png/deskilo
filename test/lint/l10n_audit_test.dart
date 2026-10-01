// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1365 — no user-facing literal outside the ones somebody decided on.
//
// #1863 — this is the one localization scanner. It used to sit beside
// `no_hardcoded_strings_test`, which pinned one shape (`Text('literal')`
// on one line); that rule now lives here at full strength, wrapped lines
// and raw strings included, and the old file is gone. This reads every
// position where a string becomes something a member sees —
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

  test('a displayed-text literal is never excused, classified or not', () {
    // HARD RULE #1 at its strictest (#1863): a Text, SelectableText or
    // TextSpan takes its words from AppLocalizations. A classification
    // covers labels and tokens elsewhere in a file, never these.
    final shown = [
      for (final f in findings)
        if (f.position == displayedText)
          '${f.path}:${f.line} "${f.literal}"',
    ];
    expect(shown, isEmpty,
        reason: 'add the key to an ARB fragment and use '
            "l10n?.key ?? 'English fallback' (HARD RULE #1).\n"
            '${shown.join('\n')}');
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
  Text(
    'A literal that wrapped is still a literal',
  ),
  Text(r'A raw string too'),
  Text('Shown beside a key', key: ValueKey('k')),
  Text('An exemption marker does not excuse it'), // l10n-exempt
  Text('reserve.title'),
  Text('{{ member }}'),
  Text('assets/help/en.md'),
  Text('\${count} items left'),
]);
''';
    final found = auditSource('lib/x.dart', caught);
    expect(found.map((f) => f.literal).toList(), [
      'Nothing here is translated',
      'Your name here',
      'Delete this booking',
      'Add a member',
      'Seat map of the ground floor',
      'A literal that wrapped is still a literal',
      'A raw string too',
      'Shown beside a key',
      'An exemption marker does not excuse it',
      'reserve.title',
      '{{ member }}',
      'assets/help/en.md',
      '\${count} items left',
    ]);
    expect(
      found.skip(5).every((f) => f.position == displayedText),
      isTrue,
      reason: 'every Text-family literal reports the strict position',
    );

    const allowed = '''
Widget build(BuildContext context) => Column(children: [
  Text(l10n?.helloThere ?? 'Hello there'),
  Text(
    l10n?.onTheNextLine ??
        'A fallback that wrapped is still a fallback',
  ),
  TextField(decoration: InputDecoration(labelText: l10n?.name ?? 'Name')),
  Text('\$stateLabel · \$count'),
  Text(
    '\${format.money(1)} · \${format.date(now)}',
  ),
  Text('\${l10n?.unread ?? 'Unread'} · \$count'),
  InputDecoration(labelText: 'reserve.title', hintText: '{{ member }}'),
  // Text('a comment is not a violation of the rule it explains'),
  /// Text('nor is a doc comment'),
  Tooltip(message: 'assets/help/en.md', child: SizedBox()),
  Semantics(identifier: 'seat-4', child: SizedBox()),
]);
''';
    expect(auditSource('lib/y.dart', allowed), isEmpty);
  });
}

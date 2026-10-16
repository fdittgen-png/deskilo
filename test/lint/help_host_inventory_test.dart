// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1853 C — the inventory of help-card hosts, and the guard against new
// ones.
//
// #1853 A gave the Reserve hub ONE help slot (`ReserveHelpHost`): the Get
// started next step, or else the tip carousel. Every other surface still
// mounts its own `HelpHint` directly. Moving those callers onto the
// shared arbiter waits for tankstellen#4480; until then this file is the
// decreasing inventory the issue asks for:
//
//   * every file that mounts a help card has its count in
//     `budgets.helpCards` of docs/design/CODE_HEALTH_BASELINE.json (#2598,
//     `dart run tool/code_health.dart --baseline`); it may only go DOWN;
//   * a file without an entry may not start mounting one: a new surface
//     gets a reviewed `--allow-new=helpCards:<file>`, or joins a host;
//   * the Get started card is mounted only by the Reserve host, so the
//     two cards can never be siblings again.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../../tool/code_health_budgets.dart';
import 'lint_sources.dart';

/// The one file allowed to mount the Get started card.
const _gettingStartedHost =
    'lib/features/reservations/presentation/widgets/getting_started_card.dart';

/// Help-card mounts in [source] (#2598: counted by the code-health tool).
({int all, int gettingStarted}) countMounts(String source) =>
    countHelpMounts(source);

/// What the tree holds, file → counts, for every file with a mount.
Map<String, ({int all, int gettingStarted})> scan(Directory root) => {
  for (final f
      in root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('core/help/help_hint.dart')))
    if (!isPartFile(f)) // #2386 — a part is read with its library
    if (countMounts(readLibrary(f)) case final c when c.all > 0)
      f.path.replaceAll(r'\', '/'): c,
};

/// The Get started card outside its host, as one line per offender; the
/// per-file inventory itself is `budgets.helpCards` (#2598).
List<String> audit(Map<String, ({int all, int gettingStarted})> found) => [
  for (final e in found.entries)
    if (e.value.gettingStarted > 0 && e.key != _gettingStartedHost)
      '${e.key}: mounts the Get started card outside the Reserve help '
          'host — the two cards would be siblings again (#1853)',
];

void main() {
  test('every help-card mount is in the budget, and it only shrinks', () {
    final problems = budgetFailures(Budgets.load(), measureBudgetActuals(),
        only: 'helpCards');
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('the Get started card is mounted only by the Reserve host', () {
    final problems = audit(scan(Directory('lib')));
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  group('the scanner is not fooled', () {
    test('a tip card is counted per mount', () {
      expect(
        countMounts('children: [\n  const HelpHint(HelpHintId.events),\n]').all,
        1,
      );
      expect(countMounts('HelpHint(a),\nHelpHint(b),').all, 2);
    });

    test('the Get started card beside the tips, outside the host, fails', () {
      final found = {
        'lib/features/reservations/presentation/screens/reserve_screen.dart':
            countMounts(
              'HelpHint(HelpHintId.reserve),\n'
              'GettingStartedCard(facts: f),',
            ),
      };
      expect(audit(found).single, contains('outside the Reserve help host'));
    });

    test('comments and declarations are not mounts', () {
      expect(
        countMounts(
          '// const HelpHint(HelpHintId.x)\n'
          'class HelpHint extends X {\n'
          '  const HelpHint(this.id, {super.key});\n'
          '  const GettingStartedCard({\n',
        ).all,
        0,
      );
    });
  });
}

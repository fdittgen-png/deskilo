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
//   * every file that mounts a help card is listed with its count, and
//     the count may only go DOWN (a lower count must lower the pin, and a
//     file at zero must leave the list) — a ratchet, not a presence list;
//   * a file not listed may not start mounting one: a new surface gets a
//     reviewed entry with its issue, or joins a host;
//   * the Get started card is mounted only by the Reserve host, so the
//     two cards can never be siblings again.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// file → help-card mounts it may hold (measured 2026-10-02).
const Map<String, int> _inventory = {
  'lib/features/calendar/presentation/screens/calendar_hub_screen.dart': 3,
  'lib/features/calendar/presentation/screens/calendar_screen.dart': 1,
  'lib/features/editor/presentation/screens/editor_screen.dart': 1,
  'lib/features/events/presentation/screens/events_screen.dart': 1,
  'lib/features/events/presentation/screens/validation_settings_screen.dart': 1,
  'lib/features/money/presentation/screens/money_screen.dart': 2,
  'lib/features/money/presentation/widgets/money_faces_view.dart': 1,
  'lib/features/profile/presentation/screens/privacy_screen.dart': 1,
  // The host itself: the tips OR the Get started card, never both.
  'lib/features/reservations/presentation/widgets/getting_started_card.dart': 2,
  'lib/features/workspace/presentation/screens/availability_screen.dart': 1,
  'lib/features/workspace/presentation/screens/members_screen.dart': 1,
    'lib/features/workspace/presentation/screens/workspace_settings_screen.dart':
      1,
  'lib/features/workspace/presentation/widgets/badge_manager_dialog.dart': 1,
  'lib/features/workspace/presentation/widgets/feature_capability_list.dart': 1,
};

/// The one file allowed to mount the Get started card.
const _gettingStartedHost =
    'lib/features/reservations/presentation/widgets/getting_started_card.dart';

final _mount = RegExp(r'\b(HelpHint|GettingStartedCard)\(');
final _definition = RegExp(
  r'class (HelpHint|GettingStartedCard)\b'
  r'|const (HelpHint|GettingStartedCard)\((\{\s*$|\{?\s*(this|super|required)\b)',
);

/// Help-card mounts in [source]: constructor calls outside comments and
/// outside the classes' own declarations.
({int all, int gettingStarted}) countMounts(String source) {
  var all = 0, gettingStarted = 0;
  for (final raw in source.split('\n')) {
    final line = raw.trimLeft();
    if (line.startsWith('//') || _definition.hasMatch(line)) continue;
    for (final m in _mount.allMatches(line)) {
      all++;
      if (m.group(1) == 'GettingStartedCard') gettingStarted++;
    }
  }
  return (all: all, gettingStarted: gettingStarted);
}

/// What the tree holds, file → counts, for every file with a mount.
Map<String, ({int all, int gettingStarted})> scan(Directory root) => {
  for (final f
      in root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('core/help/help_hint.dart')))
    if (countMounts(f.readAsStringSync()) case final c when c.all > 0)
      f.path.replaceAll(r'\', '/'): c,
};

/// The ratchet's verdict; empty means the tree honours the inventory.
List<String> audit(
  Map<String, ({int all, int gettingStarted})> found,
  Map<String, int> inventory,
) => [
  for (final e in found.entries)
    if (!inventory.containsKey(e.key))
      '${e.key}: mounts ${e.value.all} help card(s) and is not in the '
          'inventory — join a host, or add a reviewed entry with its issue'
    else if (e.value.all > inventory[e.key]!)
      '${e.key}: ${e.value.all} help cards, inventory ${inventory[e.key]} '
          '— grew'
    else if (e.value.all < inventory[e.key]!)
      '${e.key}: ${e.value.all} help cards, inventory ${inventory[e.key]} '
          '— lower the pin, the ratchet only moves when moved',
  for (final file in inventory.keys)
    if (!found.containsKey(file))
      '$file: no help card left — delete it from the inventory',
  for (final e in found.entries)
    if (e.value.gettingStarted > 0 && e.key != _gettingStartedHost)
      '${e.key}: mounts the Get started card outside the Reserve help '
          'host — the two cards would be siblings again (#1853)',
];

void main() {
  test('every help-card mount is in the inventory, and it only shrinks', () {
    final problems = audit(scan(Directory('lib')), _inventory);
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  group('the scanner is not fooled', () {
    test('a new screen with a tip card fails', () {
      final found = {
        'lib/x/new_screen.dart': countMounts(
          'children: [\n  const HelpHint(HelpHintId.events),\n]',
        ),
      };
      expect(audit(found, const {}).single, contains('not in the inventory'));
    });

    test('a second card on a listed screen fails; a removed one asks for '
        'the pin to come down', () {
      const file = 'lib/a.dart';
      final two = countMounts('HelpHint(a),\nHelpHint(b),');
      expect(audit({file: two}, const {file: 1}).single, contains('grew'));
      final none = <String, ({int all, int gettingStarted})>{};
      expect(audit(none, const {file: 1}).single, contains('delete it'));
    });

    test('the Get started card beside the tips, outside the host, fails', () {
      final found = {
        'lib/features/reservations/presentation/screens/reserve_screen.dart':
            countMounts(
              'HelpHint(HelpHintId.reserve),\n'
              'GettingStartedCard(facts: f),',
            ),
      };
      expect(
        audit(found, const {
          'lib/features/reservations/presentation/screens/reserve_screen.dart':
              2,
        }).single,
        contains('outside the Reserve help host'),
      );
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

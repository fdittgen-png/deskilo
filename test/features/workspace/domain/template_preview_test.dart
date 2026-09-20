// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1280 S2 — the preview is the server's change-set; the client only
// reads it. And the group vocabulary is the server's, pinned.
import 'dart:io';

import 'package:deskilo/features/workspace/domain/template_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every group the server declares is a TemplateGroup, and no more', () {
    // The latest restatement of deployable_entities() with its groups.
    final sql = File('supabase/migrations/0219_import_merge_mode.sql')
        .readAsStringSync();
    final declared = RegExp(r"'group', '([a-z_]+)'")
        .allMatches(sql)
        .map((m) => m.group(1)!)
        .toSet();
    final known = {
      for (final g in TemplateGroup.values)
        if (g != TemplateGroup.unknown) g.wire,
    };
    expect(declared.difference(known), isEmpty,
        reason: 'a server group the app cannot name');
    expect(declared, isNotEmpty);
  });

  test('new is ticked, change is offered unticked, matching and attention '
      'are not offered', () {
    final p = TemplatePreview.fromJson(<String, dynamic>{
      'compatibility': 'supported',
      'groups': [
        {'group': 'space', 'state': 'new', 'items': [<String, Object?>{}, <String, Object?>{}, <String, Object?>{}]},
        {'group': 'hours_booking', 'state': 'change', 'items': [<String, Object?>{}]},
        {'group': 'wording', 'state': 'matching', 'items': <Object?>[]},
        {
          'group': 'pricing_credits',
          'state': 'needs_attention',
          'items': [<String, Object?>{}],
          'reason': 'fee_schedule_replaced_whole'
        },
        {'group': 'from_the_future', 'state': 'new', 'items': [<String, Object?>{}]},
      ],
    });
    final byWire = {for (final g in p.groups) g.wire: g};
    expect(byWire['space']!.selectedByDefault, isTrue);
    expect(byWire['hours_booking']!.selectable, isTrue);
    expect(byWire['hours_booking']!.selectedByDefault, isFalse);
    expect(byWire['wording']!.selectable, isFalse);
    expect(byWire['pricing_credits']!.selectable, isFalse);
    expect(byWire['pricing_credits']!.reason, 'fee_schedule_replaced_whole');
    expect(byWire['from_the_future']!.selectable, isFalse,
        reason: 'a group this build cannot name is shown, never applied');
    expect(p.changesFor({'space', 'hours_booking'}), 4);
    expect(p.applicable, isTrue);
  });

  test('#1280 S4 — a group customized here is offered, never pre-ticked', () {
    final p = TemplatePreview.fromJson(<String, dynamic>{
      'compatibility': 'supported',
      'groups': [
        {
          'group': 'calendar_navigation',
          'state': 'new',
          'customized': true,
          'items': [<String, Object?>{}],
        },
        {'group': 'space', 'state': 'new', 'items': [<String, Object?>{}]},
      ],
    });
    final cal = p.groups.first;
    expect(cal.customized, isTrue);
    expect(cal.selectable, isTrue);
    expect(cal.selectedByDefault, isFalse);
    expect(p.groups.last.customized, isFalse);
    expect(p.groups.last.selectedByDefault, isTrue);
  });

  test('not supported is not applicable', () {
    final p = TemplatePreview.fromJson(<String, dynamic>{
      'compatibility': 'not_supported',
      'reason': 'template schema 9 is newer than this server',
      'groups': <Object?>[],
    });
    expect(p.applicable, isFalse);
    expect(p.reason, contains('newer'));
  });
}

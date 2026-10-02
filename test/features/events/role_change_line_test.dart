// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2085 — the activity line for a role given or taken back.
//
// Invariant: a grant of one of the workspace's own roles is recorded by
// `assign_workspace_role` (0340) with the role's key, its names as they
// read that day and the direction, and no `make_admin`. The activity
// line names the role in the reader's language and the member it was
// given to; the Administrator role's quorum request keeps its own line.
// A record without names still reads, by the role's key.
import 'package:deskilo/core/i18n/money_format.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/presentation/event_lines.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvent _event(Map<String, dynamic> payload) => WorkspaceEvent(
      id: 'e1',
      workspaceId: 'ws-1',
      type: EventType.roleChange,
      action: EventAction.created,
      actorMemberId: 'owner',
      subjectMemberId: 'lea',
      payload: payload,
      status: EventStatus.applied,
      createdAt: DateTime.utc(2026, 10, 2),
    );

const _names = {'owner': 'Flo', 'lea': 'Léa'};

Future<AppLocalizations> _l10n(String locale) =>
    AppLocalizations.delegate.load(Locale(locale));

String _line(AppLocalizations l10n, Map<String, dynamic> payload) => eventLine(
      l10n,
      _event(payload),
      _names,
      const {},
      MoneyFormat('EUR'),
    );

void main() {
  const treasurer = {
    'role_key': 'tresorier',
    'role_names': {'en': 'Treasurer', 'fr': 'Trésorier·ère'},
  };

  test('a role given and taken back reads with its name and the member',
      () async {
    final en = await _l10n('en');
    expect(_line(en, {...treasurer, 'assign': true}),
        'Flo gives the role Treasurer to Léa');
    expect(_line(en, {...treasurer, 'assign': false}),
        'Flo takes back the role Treasurer from Léa');
  });

  test("the role's name follows the reader's language", () async {
    final fr = await _l10n('fr');
    expect(_line(fr, {...treasurer, 'assign': true}),
        'Flo attribue le rôle Trésorier·ère à Léa');
  });

  test('a record without names reads by the key, and the Administrator '
      'request keeps its own line', () async {
    final en = await _l10n('en');
    expect(_line(en, {'role_key': 'tresorier', 'assign': true}),
        'Flo gives the role tresorier to Léa');
    expect(_line(en, {'make_admin': true}),
        'Flo asks to give the Administrator role for Léa');
    expect(_line(en, {'make_admin': false}),
        'Flo asks to take back the Administrator role for Léa');
  });

  test('roleNameIn: the language, then English, then the fallback', () {
    expect(roleNameIn(const {'fr': 'Trésorier', 'en': 'Treasurer'}, 'fr', 'k'),
        'Trésorier');
    expect(roleNameIn(const {'en': 'Treasurer'}, 'de', 'k'), 'Treasurer');
    expect(roleNameIn(const {'en': '  '}, 'en', 'k'), 'k');
    expect(roleNameIn(null, 'en', 'k'), 'k');
  });
}

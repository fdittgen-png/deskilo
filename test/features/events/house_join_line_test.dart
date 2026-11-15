// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4008 — a join from another house of the organisation says where the
// person comes from, and whether this house's welcome decided it; any other
// join reads as before.
import 'package:deskilo/core/i18n/money_format.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/presentation/event_lines.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

String _line(AppLocalizations l10n, Map<String, dynamic> payload) => eventLine(
  l10n,
  WorkspaceEvent(
    id: 'e1',
    workspaceId: 'ws-6',
    type: EventType.memberJoin,
    action: EventAction.created,
    actorMemberId: 'bruno',
    subjectMemberId: 'bruno',
    payload: payload,
    status: EventStatus.pending,
    createdAt: DateTime.utc(2026, 11, 15),
  ),
  const {'bruno': 'Bruno'},
  const {},
  MoneyFormat('EUR', locale: null),
);

void main() {
  test(
    'a join from another house names it, and the welcome that decided',
    () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      const from = {'from_workspace_name': 'Atelier du Marché'};
      expect(_line(en, from), 'Bruno asks to join, from Atelier du Marché');
      expect(
        _line(en, {...from, 'by': 'house_welcome'}),
        "Bruno joined from Atelier du Marché, welcomed by this house's setting",
      );
      expect(
        _line(en, const {}),
        isNot(contains('Atelier du Marché')),
        reason: 'a join with a code reads as before',
      );
    },
  );
}

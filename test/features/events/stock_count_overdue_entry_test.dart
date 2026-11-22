// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4295: the notice that a cycle count task is still open past its due day, in
// every language: it names the plan; once the task is complete it says so.
// Filed under money, read with manageStock, told by nobody.
import 'package:deskilo/core/demo/data/event_visibility.dart';
import 'package:deskilo/core/i18n/money_format.dart';
import 'package:deskilo/features/events/domain/notification_feed.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/presentation/event_labels.dart';
import 'package:deskilo/features/events/presentation/event_lines.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvent _notice({String? ended}) => WorkspaceEvent(
  id: 'notice-$ended',
  workspaceId: 'ws-1',
  type: EventType.fromDb('stock_count_overdue'),
  action: EventAction.created,
  actorMemberId: 'owner',
  subjectMemberId: 'owner',
  payload: {'task': 't-1', 'plan': 'Main aisle', 'due_on': '2026-11-01', 'ended': ?ended},
  status: EventStatus.applied,
  createdAt: DateTime.utc(2026, 11),
);

String _line(AppLocalizations l10n, WorkspaceEvent event) => eventLine(
  l10n,
  event,
  const {'owner': 'Florian'},
  const {},
  MoneyFormat('EUR', locale: null),
);

void main() {
  for (final language in const ['en', 'fr', 'de', 'es', 'it']) {
    test('$language: the notice names the plan, and its end', () {
      final l10n = lookupAppLocalizations(Locale(language));
      final open = _line(l10n, _notice());
      expect(open, l10n.eventStockCountOverdue('Main aisle'));
      expect(open, contains('Main aisle'));
      expect(
        _line(l10n, _notice(ended: 'complete')),
        '$open · ${l10n.eventStockCountOverdueEnded}',
      );
      expect(open, isNot(contains('Florian')), reason: 'a job acts');
      expect(
        eventTypeLabel(l10n, EventType.stockCountOverdue),
        l10n.eventTypeStockCountOverdue,
      );
    });
  }

  test('the wire word is read, filed under money and read with manageStock', () {
    final notice = _notice();
    expect(notice.type, EventType.stockCountOverdue);
    expect(categoryOfEvent(notice), NotificationCategory.money);
    expect(eventTypeViewPermissions('stock_count_overdue'), {
      WorkspacePermission.manageStock,
    });
  });
}

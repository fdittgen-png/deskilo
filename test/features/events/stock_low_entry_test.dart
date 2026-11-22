// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4294: the low-stock notice in the inbox, in every language: which item at which site (by its
// address), what is on hand and the reorder point in the item's unit; once the stock rose above the
// point it says so. Filed under money, read with manageStock or managePurchases (and not by a member
// without them), and its row opens the Reorder page. The Demo's shop has two items below their point.
import 'package:deskilo/core/demo/data/event_visibility.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/i18n/money_format.dart';
import 'package:deskilo/features/events/domain/notification_feed.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/presentation/event_destination.dart';
import 'package:deskilo/features/events/presentation/event_labels.dart';
import 'package:deskilo/features/events/presentation/event_lines.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvent _low({String? ended, String item = 'beans'}) => WorkspaceEvent(
  id: 'low-$item-$ended',
  workspaceId: 'ws-1',
  type: EventType.fromDb('stock_low'),
  action: EventAction.created,
  actorMemberId: 'owner',
  subjectMemberId: 'owner',
  payload: {
    'point': 'p1',
    'item_id': item,
    'site_id': 'main',
    'on_hand': '12.500000',
    'reorder_point': '20.000000',
    'ended': ?ended,
  },
  status: EventStatus.applied,
  createdAt: DateTime.utc(2026, 11),
);

final _money = MoneyFormat('EUR', locale: null);
const _names = {
  'owner': 'Florian',
  'item:beans': 'Coffee beans',
  'unit:beans': 'kg',
  'place:main': 'MAIN',
};

String _line(AppLocalizations l10n, WorkspaceEvent e, [Map<String, String> names = _names]) =>
    eventLine(l10n, e, names, const {}, _money);

void main() {
  for (final language in const ['en', 'fr', 'de', 'es', 'it']) {
    test('$language: the notice names the item, the site, what is on hand and the point; its end', () {
      final l10n = lookupAppLocalizations(Locale(language));
      final open = _line(l10n, _low());
      expect(
        open,
        l10n.eventStockLow(
          'Coffee beans',
          'MAIN',
          l10n.stockQuantityWithUnit('12.5', 'kg'),
          l10n.stockQuantityWithUnit('20', 'kg'),
        ),
      );
      expect(_line(l10n, _low(ended: '2026-11-02')), '$open · ${l10n.eventStockLowEnded}');
      expect(open, isNot(contains('Florian')), reason: 'the job acts, nobody did');
      expect(eventTypeLabel(l10n, EventType.stockLow), l10n.eventTypeStockLow);
    });

    test('$language: a name that could not be read is said in words, never a raw id', () {
      final l10n = lookupAppLocalizations(Locale(language));
      final line = _line(l10n, _low(item: 'unknown-item'), const {});
      expect(line, contains(l10n.eventStockLowItemFallback));
      expect(line, contains(l10n.eventStockLowSiteFallback));
      expect(line, isNot(contains('unknown-item')));
    });
  }

  test('the wire word is read, filed under money, read with the stock or purchases right, and opens the Reorder page', () {
    final notice = _low();
    expect(notice.type, EventType.stockLow);
    expect(categoryOfEvent(notice), NotificationCategory.money);
    expect(eventTypeViewPermissions('stock_low'), {
      WorkspacePermission.manageStock,
      WorkspacePermission.managePurchases,
    });
    expect(eventDestination(notice), '/stock/reorder');
  });

  test('the Demo\'s two items below their point have told the owner; a plain member does not read them', () async {
    final owner = DemoFixture.build()..becomePersona(DemoPersona.owner);
    final seen = [
      for (final e in await owner.events.fetchEvents('ws-1'))
        if (e.type == EventType.stockLow) '${e.payload['item_id']}',
    ];
    expect(seen..sort(), ['demo-item-beans', 'demo-item-syrup']);
    final member = DemoFixture.build()..becomePersona(DemoPersona.member);
    expect(
      [for (final e in await member.events.fetchEvents('ws-1')) if (e.type == EventType.stockLow) e],
      isEmpty,
    );
  });
}

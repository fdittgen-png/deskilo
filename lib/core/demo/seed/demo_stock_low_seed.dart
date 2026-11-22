// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4294 -- the shop's two items below their reorder point (the coffee beans and the syrup) have told
// the owner once each, as the server tells it: the inbox row names the item and the site, what is on
// hand and the point, and opens the Reorder page.
import '../../../features/events/domain/workspace_event.dart';
import '../data/event_repository.dart';

/// The point's own site (a business field of the notice, not a row stamp).
const _siteKey = 'site_id';

WorkspaceEvent _low(String item, String onHand, String point, Duration ago, DateTime now) => WorkspaceEvent(
  id: 'demo-stock-low-$item',
  workspaceId: 'ws-1',
  type: EventType.stockLow,
  action: EventAction.created,
  actorMemberId: 'member-1',
  subjectMemberId: 'member-1',
  payload: {
    'point': 'demo-point-$item',
    'item_id': item,
    _siteKey: 'demo-place-main',
    'on_hand': onHand,
    'reorder_point': point,
  },
  status: EventStatus.applied,
  createdAt: now.subtract(ago),
);

/// Adds the low-stock notices to the Demo's [events].
void seedDemoStockLow(FakeEventRepository events, DateTime now) => events.events
  ..add(_low('demo-item-beans', '12.500000', '20.000000', const Duration(days: 2), now))
  ..add(_low('demo-item-syrup', '0.999999', '5.000000', const Duration(days: 3), now));

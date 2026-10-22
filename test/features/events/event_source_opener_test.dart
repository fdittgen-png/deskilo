// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2573 — the decision on an expense request opens the purchase document it
// was filed as. The events page asks core for an opener per event type and
// names no other feature; money supplies the expense one while purchases
// are on.
import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/core/navigation/event_sources.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/presentation/widgets/pending_decisions_section.dart';
import 'package:deskilo/features/money/presentation/purchase_source_opener.dart';
import 'package:deskilo/features/money/providers/expense_schedule_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

class _Opener implements EventSourceOpener {
  _Opener({required this.found});
  final bool found;
  final opened = <(String, String)>[];

  @override
  Future<bool> open(
    BuildContext context,
    String workspaceId,
    String eventId,
  ) async {
    opened.add((workspaceId, eventId));
    return found;
  }
}

WorkspaceEvent _event(String id, EventType type) => WorkspaceEvent(
  id: id,
  workspaceId: 'ws-1',
  type: type,
  action: EventAction.created,
  status: EventStatus.pending,
  actorMemberId: 'member-2',
  subjectMemberId: 'member-2',
  payload: const {},
  createdAt: kTestNow.subtract(const Duration(minutes: 1)),
);

Future<void> _pump(WidgetTester tester, _Opener opener) => pumpApp(
  tester,
  Scaffold(
    body: SingleChildScrollView(
      child: PendingDecisionsSection(
        pending: [
          _event('expense-1', EventType.expense),
          _event('payment-1', EventType.payment),
        ],
      ),
    ),
  ),
  overrides: [
    ...standardTestOverrides(
      workspace: FakeWorkspaceRepository.withWorkspace(),
    ),
    eventSourceOpenersProvider.overrideWithValue({'expense': opener}),
  ],
);

void main() {
  testWidgets('an expense request opens its purchase document; a payment '
      'has no such button', (tester) async {
    final opener = _Opener(found: true);
    await _pump(tester, opener);
    await tester.pumpAndSettle();
    const source = ValueKey('pending-decisions-section-event-source-expense-1');
    expect(find.byKey(source), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('pending-decisions-section-event-source-payment-1'),
      ),
      findsNothing,
    );
    await tester.tap(find.byKey(source));
    await tester.pumpAndSettle();
    expect(opener.opened.single.$2, 'expense-1');
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a request filed as nothing the reader may see says so', (
    tester,
  ) async {
    await _pump(tester, _Opener(found: false));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('pending-decisions-section-event-source-expense-1'),
      ),
    );
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
  });

  test('money supplies the expense opener only while purchases are on', () {
    ProviderContainer scope(Set<WorkspaceFeature> features) {
      final c = ProviderContainer(
        overrides: [
          eventSourceOpenersFromMoney,
          enabledFeaturesSyncProvider.overrideWithValue(features),
          purchaseRepositoryProvider.overrideWithValue(
            FakePurchaseRepository(),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    expect(
      scope({WorkspaceFeature.purchases}).read(eventSourceOpenersProvider),
      {'expense': isA<PurchaseSourceOpener>()},
    );
    expect(scope(const {}).read(eventSourceOpenersProvider), isEmpty);
  });
}

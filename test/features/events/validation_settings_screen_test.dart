// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Card counts: default + 17 domains (#828 added shared expenses; #767 added price
// negotiation and scheduled expense; #833 added the early-departure correction and
// the usage-record removal).

import 'package:deskilo/features/events/domain/validation_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/validation_settings.dart';

void main() {
  testWidgets(
      'renders the default card and one card per event type with the '
      'effective (built-in) values', (tester) async {
    await pumpValidationSettings(tester);

    expect(find.text('Default policy'), findsOneWidget);
    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Service'), findsOneWidget);
    expect(find.text('Extra half-days'), findsOneWidget);
    expect(find.text('Role change'), findsOneWidget);
    expect(find.text('Reservation'), findsOneWidget);
    // #816 — no Adjustment card: nothing ever emitted that event type.
    expect(find.text('Adjustment'), findsNothing);

    // No stored rows: every card shows the built-in defaults and
    // inherits. #1221 — the rule reads as the PROCESS now: who asks,
    // who decides and how many, and what happens then.
    expect(find.text('Someone asks · Never your own'), findsNWidgets(24));
    expect(find.text('All admins — any 1'), findsNWidgets(24));
    expect(find.text('it takes effect'), findsNWidgets(24));
    expect(find.text('Inherits default'), findsNWidgets(24));
    expect(find.text('Customized'), findsNothing);
  });

  testWidgets('editing the default policy persists it via the repository',
      (tester) async {
    final events = await pumpValidationSettings(tester);

    await tester.tap(find.text('Default policy'));
    await tester.pumpAndSettle();

    // The picker offers "All admins" plus the two non-owner admins.
    expect(find.text('All admins'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Bo'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.tap(find.text('Owner must always validate'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = events.policies.single;
    expect(stored.workspaceId, 'ws-1');
    expect(stored.eventType, isNull);
    expect(stored.requiredCount, 2);
    expect(stored.adminsMayValidate, isTrue);
    expect(stored.eligibleAdminIds, isEmpty);
    expect(stored.ownerRequired, isTrue);

    // The default card now carries its own row.
    expect(find.text('Customized'), findsOneWidget);
    expect(find.text('Validation rule saved.'), findsOneWidget);
  });

  testWidgets('picking specific admins persists their ids', (tester) async {
    final events = await pumpValidationSettings(tester);

    await tester.tap(find.text('Payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = events.policies.single;
    expect(stored.eventType, 'payment');
    expect(stored.eligibleAdminIds, ['member-2']);
  });

  testWidgets('turning admins off hides the admin picker', (tester) async {
    await pumpValidationSettings(tester);

    await tester.tap(find.text('Default policy'));
    await tester.pumpAndSettle();
    expect(find.text('All admins'), findsOneWidget);

    await tester.tap(find.text('Admins may validate'));
    await tester.pumpAndSettle();

    expect(find.text('All admins'), findsNothing);
    expect(find.text('Ana'), findsNothing);
    expect(find.text('Owner only'), findsOneWidget);
  });

  testWidgets(
      'a required count above the eligible pool blocks save with a message',
      (tester) async {
    // Only the owner exists; with admins switched off the pool is 1 (+1
    // for the subject's own accept), so 3 can never be reached.
    final events =
        await pumpValidationSettings(tester, otherMembers: const []);

    await tester.tap(find.text('Default policy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admins may validate'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Not enough eligible validators.'), findsOneWidget);
    expect(events.policies, isEmpty);
    // The sheet stayed open — nothing was saved.
    expect(find.text('Validation rule saved.'), findsNothing);
  });

  testWidgets('#629 — the auto-validation switches exist ONLY on the '
      'booking-deletion card, and default OFF', (tester) async {
    await pumpValidationSettings(tester);

    // Every other card: no trace of the exception.
    await tester.tap(find.text('Payment'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auto-validate-owner')), findsNothing);
    expect(find.byKey(const Key('auto-validate-admin')), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Booking deletion'));
    await tester.pumpAndSettle();
    final owner = find.byKey(const Key('auto-validate-owner'));
    final admin = find.byKey(const Key('auto-validate-admin'));
    expect(tester.widget<SwitchListTile>(owner).value, isFalse);
    expect(tester.widget<SwitchListTile>(admin).value, isFalse);
  });

  testWidgets('#629 — toggling both auto-validation switches persists '
      'them on the reservation_delete row', (tester) async {
    final events = await pumpValidationSettings(tester);

    await tester.tap(find.text('Booking deletion'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('auto-validate-owner')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('auto-validate-admin')));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = events.policies.single;
    expect(stored.eventType, 'reservation_delete');
    expect(stored.autoValidateOwner, isTrue);
    expect(stored.autoValidateAdmin, isTrue);
    // The quorum fields are untouched by the new switches.
    expect(stored.requiredCount, 1);
    expect(stored.adminsMayValidate, isTrue);
    expect(find.text('Validation rule saved.'), findsOneWidget);

    // Re-opening reflects what was stored, and turning one back off
    // persists that too.
    await tester.tap(find.text('Booking deletion'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('auto-validate-admin')))
          .value,
      isTrue,
    );
    await tester.tap(find.byKey(const Key('auto-validate-admin')));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(events.policies.single.autoValidateAdmin, isFalse);
    expect(events.policies.single.autoValidateOwner, isTrue);
  });

  testWidgets('a per-type card shows "Customized" once its own row exists',
      (tester) async {
    await pumpValidationSettings(
      tester,
      policies: const [
        ValidationPolicy(
          id: 'vp-1',
          workspaceId: 'ws-1',
          eventType: 'payment',
          requiredCount: 2,
          adminsMayValidate: true,
          eligibleAdminIds: [],
          ownerRequired: true,
        ),
      ],
    );

    expect(find.text('Customized'), findsOneWidget);
    expect(find.text('Inherits default'), findsNWidgets(23));
    // #1221 — the customized rule, read as its process: two admins
    // decide, and the owner is always one of the accepts.
    expect(find.text('All admins — any 2'), findsOneWidget);
    expect(find.text('and the owner, always'), findsOneWidget);
  });
}

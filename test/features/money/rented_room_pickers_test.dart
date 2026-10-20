// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2575 -- a rented room is also opened to chosen plans and members from its
// form: plans are chips, members are picked from the space's own and shown as
// removable chips, the roles already chosen stay, and "open to everyone" hides
// the pickers.
import 'package:deskilo/core/demo/data/room_rental_repository.dart';
import 'package:deskilo/core/demo/seed/demo_room_seed.dart';
import 'package:deskilo/core/roles/audience_roles.dart';
import 'package:deskilo/features/money/domain/room_rental.dart' show RoomPlan;
import 'package:deskilo/features/money/domain/supplier.dart';
import 'package:deskilo/features/money/presentation/widgets/rented_rooms_sheet.dart';
import 'package:deskilo/features/money/providers/room_rental_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two pumps past the dialog and menu animations; no pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<FakeRoomRentalRepository> _open(WidgetTester tester) async {
  final repo = seedDemoRooms(DateTime(2026, 10, 18))
    ..plans.addAll(const [
      RoomPlan(id: 'plan-flex', name: 'Flex'),
      RoomPlan(id: 'plan-resident', name: 'Resident'),
    ]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roomRentalRepositoryProvider.overrideWithValue(repo),
        suppliersProvider.overrideWith(
          (ref, ws) async => const [
            Supplier(id: 's1', number: '1', name: 'Immobilière du Midi'),
          ],
        ),
        audienceRolesProvider.overrideWithValue(const [
          AudienceRole(id: 'role-staff', names: {'en': 'Staff'}),
        ]),
        audienceMembersProvider.overrideWithValue(const {
          'm-ada': 'Ada Lovelace',
          'm-bo': 'Bo Peep',
        }),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RentedRoomsView(workspaceId: 'ws'),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
  const edit = ValueKey('room-edit-demo-room-loft');
  await tester.ensureVisible(find.byKey(edit));
  await tester.tap(find.byKey(edit));
  await _settle(tester);
  await tester.tap(find.byKey(const ValueKey('room-rent-lessor')));
  await _settle(tester);
  await tester.tap(find.text('Immobilière du Midi').last);
  await _settle(tester);
  await tester.tap(find.byKey(const ValueKey('room-rent-from')));
  await _settle(tester);
  await tester.tap(find.text('OK'));
  await _settle(tester);
  return repo;
}

void main() {
  testWidgets('a plan and two members are the rental audience', (tester) async {
    final repo = await _open(tester);
    await tester.ensureVisible(find.text('Also open to these plans'));
    await tester.tap(find.byKey(const ValueKey('room-rent-plan-plan-flex')));
    await tester.pump();
    for (final name in ['Ada Lovelace', 'Bo Peep']) {
      await tester.ensureVisible(
        find.byKey(const ValueKey('room-rent-member-add')),
      );
      await tester.tap(find.byKey(const ValueKey('room-rent-member-add')));
      await _settle(tester);
      await tester.tap(find.text(name).last);
      await _settle(tester);
    }
    expect(
      find.byKey(const ValueKey('room-rent-member-m-ada')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('room-rent-member-m-bo')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('room-rent-save')));
    await _settle(tester);
    final loft = (await repo.fetchOverview('ws')).rentals.last;
    expect(loft.audience.map((e) => e.planId).whereType<String>(), [
      'plan-flex',
    ]);
    expect(loft.audience.map((e) => e.memberId).whereType<String>().toSet(), {
      'm-ada',
      'm-bo',
    });
    expect(loft.audienceAll, isFalse);
  });

  testWidgets('a picked member can be removed again', (tester) async {
    await _open(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('room-rent-member-add')),
    );
    await tester.tap(find.byKey(const ValueKey('room-rent-member-add')));
    await _settle(tester);
    await tester.tap(find.text('Ada Lovelace').last);
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('room-rent-member-m-ada')),
      findsOneWidget,
    );
    tester
        .widget<InputChip>(find.byKey(const ValueKey('room-rent-member-m-ada')))
        .onDeleted!();
    await _settle(tester);
    expect(find.byKey(const ValueKey('room-rent-member-m-ada')), findsNothing);
  });

  testWidgets('open to everyone hides the pickers', (tester) async {
    await _open(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('room-rent-all')));
    await tester.tap(find.byKey(const ValueKey('room-rent-all')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('room-rent-plan-plan-flex')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('room-rent-member-add')), findsNothing);
  });
}

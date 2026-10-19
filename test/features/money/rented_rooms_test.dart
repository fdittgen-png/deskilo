// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2568 -- the rented rooms screen: it lists the floors, the rooms and each
// rental with its window and what a member pays; marking a floor external is
// refused while it holds a rental; renting a room needs a lessor and a first
// day, and a saved rental is what the server would hold.
import 'package:deskilo/core/demo/seed/demo_room_seed.dart';
import 'package:deskilo/features/money/application/room_rental_commands.dart';
import 'package:deskilo/features/money/domain/room_level_kind.dart';
import 'package:deskilo/features/money/domain/room_rental.dart';
import 'package:deskilo/features/money/domain/supplier.dart';
import 'package:deskilo/features/money/presentation/widgets/rented_rooms_sheet.dart';
import 'package:deskilo/features/money/providers/room_rental_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget body, List<Override> overrides) => ProviderScope(
  key: UniqueKey(),
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: body)),
  ),
);

final _today = DateTime(2026, 10, 18);

void main() {
  test(
    'a rental cannot end before it starts, and a negative fee is not sent',
    () async {
      final repo = seedDemoRooms(_today);
      final commands = RoomRentalCommands(repo);
      RoomRentalCommand command({DateTime? until, int fee = 1500}) =>
          RoomRentalCommand(
            officeId: 'demo-room-loft',
            supplierId: 's1',
            availableFrom: DateTime(2027, 3),
            availableUntil: until,
            status: RoomRentalStatus.active,
            fees: [RoomFee(unit: RoomFeeUnit.halfDay, feeCents: fee)],
          );
      expect(
        await commands.save('ws', command(until: DateTime(2027, 2))),
        isNull,
      );
      expect(await commands.save('ws', command(fee: -1)), isNull);
      expect((await repo.fetchOverview('ws')).rentals, hasLength(1));
      expect(await commands.save('ws', command()), isNotNull);
      expect((await repo.fetchOverview('ws')).rentals, hasLength(2));
    },
  );

  test('the member is offered the general fee for an active room, nothing for a draft', () async {
    final repo = seedDemoRooms(_today);
    final offer = await repo.fetchOffer('ws', 'demo-room-studio');
    expect(offer.feeFor(RoomFeeUnit.halfDay), 1500);
    await expectLater(
      repo.fetchOffer('ws', 'demo-room-loft'),
      throwsStateError,
    );
  });

  test('a floor with a rental stays external', () async {
    final repo = seedDemoRooms(_today);
    await expectLater(
      repo.setLevelKind('ws', 'demo-level-annex', LevelKind.own),
      throwsStateError,
    );
    await repo.setLevelKind('ws', 'demo-level-own', LevelKind.external);
    expect((await repo.fetchOverview('ws')).levels.map((l) => l.kind), [
      LevelKind.external,
      LevelKind.external,
    ]);
  });

  testWidgets(
    'the sheet lists the rental with its window and fee, and renting the loft saves it',
    (tester) async {
      final repo = seedDemoRooms(_today);
      await tester.pumpWidget(
        _app(const RentedRoomsView(workspaceId: 'ws'), [
          roomRentalRepositoryProvider.overrideWithValue(repo),
          suppliersProvider.overrideWith(
            (ref, ws) async => const [
              Supplier(
                id: 'demo-supplier-immo',
                number: '1',
                name: 'Immobilière du Midi',
              ),
            ],
          ),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Annex, 1st floor · Studio'), findsOneWidget);
      expect(find.textContaining('400.00'), findsOneWidget);
      expect(find.textContaining('15.00'), findsOneWidget);
      expect(find.text('Open to every member'), findsWidgets);
      expect(find.text('Not rented yet'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('room-edit-demo-room-loft')));
      await tester.tap(find.byKey(const ValueKey('room-edit-demo-room-loft')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('room-rent-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('room-rent-invalid')), findsOneWidget);
      expect((await repo.fetchOverview('ws')).rentals, hasLength(1));

      await tester.tap(find.byKey(const ValueKey('room-rent-lessor')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Immobilière du Midi').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('room-rent-from')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('room-rent-cost')),
        '250',
      );
      await tester.enterText(find.byKey(const ValueKey('room-rent-fee')), '12');
      await tester.tap(find.byKey(const ValueKey('room-rent-save')));
      await tester.pumpAndSettle();
      final loft = (await repo.fetchOverview('ws')).rentals.last;
      expect(loft.officeId, 'demo-room-loft');
      expect(loft.costCents, 25000);
      expect(loft.status, RoomRentalStatus.draft);
      expect(loft.fees.single.feeCents, 1200);
      expect(find.byKey(const ValueKey('room-rent-save')), findsNothing);
    },
  );
}

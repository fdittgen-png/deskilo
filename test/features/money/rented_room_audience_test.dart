// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2575 -- a rented room is opened to chosen roles from its form: the roles
// the space defined are offered as chips, the chosen ones are what the
// rental saves as its audience, and the room is then not open to everyone.
import 'package:deskilo/core/demo/seed/demo_room_seed.dart';
import 'package:deskilo/core/roles/audience_roles.dart';
import 'package:deskilo/features/money/domain/supplier.dart';
import 'package:deskilo/features/money/presentation/widgets/rented_rooms_sheet.dart';
import 'package:deskilo/features/money/providers/room_rental_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the chosen roles are the rental audience', (tester) async {
    final repo = seedDemoRooms(DateTime(2026, 10, 18));
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
            AudienceRole(id: 'role-trainers', names: {'en': 'Trainers'}),
            AudienceRole(id: 'role-staff', names: {'en': 'Staff'}),
          ]),
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
    await tester.pumpAndSettle();
    const edit = ValueKey('room-edit-demo-room-loft');
    await tester.ensureVisible(find.byKey(edit));
    await tester.tap(find.byKey(edit));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('room-rent-lessor')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Immobilière du Midi').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('room-rent-from')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Also open to these roles'));
    await tester.tap(find.byKey(const ValueKey('room-rent-role-role-trainers')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('room-rent-save')));
    await tester.pumpAndSettle();
    final loft = (await repo.fetchOverview('ws')).rentals.last;
    expect(loft.officeId, 'demo-room-loft');
    expect(loft.audience.map((e) => e.roleId), ['role-trainers']);
    expect(loft.audienceAll, isFalse);
  });
}

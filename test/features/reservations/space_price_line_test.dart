// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2575 -- the space sheet tells the member what a rented room costs THEM and
// until when it is rented, and nothing about it when it is not offered to
// them, when the flag is off, or when the resource is not a room. The whole-
// space price line keeps its key and its place.
import 'package:deskilo/features/reservations/domain/room_offer.dart';
import 'package:deskilo/features/reservations/presentation/widgets/space_price_line.dart';
import 'package:deskilo/features/reservations/providers/place_feedback_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

class _Offers implements RoomOfferRepository {
  _Offers(this.answer);

  final Future<RoomOfferView> Function(String officeId) answer;
  final asked = <String>[];

  @override
  Future<RoomOfferView> fetch(String workspaceId, String officeId) {
    asked.add(officeId);
    return answer(officeId);
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Offers offers, {
  bool flag = true,
  String? officeId = 'room-1',
  String? priceLine,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: {'levelBooking': true, 'externalRooms': flag},
          ),
        ),
        roomOfferRepositoryProvider.overrideWithValue(offers),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SpacePriceLine(
            workspaceId: 'ws-1',
            priceLine: priceLine,
            officeId: officeId,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a rented room shows its last day and what a use costs the member', (tester) async {
    final offers = _Offers(
      (_) async => RoomOfferView.fromJson({
        'currency': 'EUR',
        'available_until': '2027-08-31',
        'fees': [
          {'unit': 'half_day', 'fee_cents': 1500},
        ],
      }),
    );
    await _pump(tester, offers);
    expect(find.byKey(const ValueKey('space-room-window')), findsOneWidget);
    expect(find.textContaining('available until'), findsOneWidget);
    expect(find.byKey(const ValueKey('space-room-fee-half_day')), findsOneWidget);
    expect(find.textContaining('15.00'), findsOneWidget);
    expect(find.textContaining('per half day'), findsOneWidget);
    expect(offers.asked, ['room-1']);
  });

  testWidgets('an open-ended rental says so and a free room shows no fee', (tester) async {
    final offers = _Offers(
      (_) async => RoomOfferView.fromJson({'currency': 'EUR', 'available_until': null, 'fees': <Object>[]}),
    );
    await _pump(tester, offers);
    expect(find.textContaining('no end date'), findsOneWidget);
    expect(find.textContaining('per half day'), findsNothing);
  });

  testWidgets('a room not offered to the member shows nothing, not an error', (tester) async {
    final offers = _Offers((_) async => throw StateError('that room is not open to you'));
    await _pump(tester, offers);
    expect(find.byKey(const ValueKey('space-room-window')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with the flag off, or for a resource that is not a room, nothing is even asked', (tester) async {
    final off = _Offers((_) async => RoomOfferView.fromJson({'currency': 'EUR', 'fees': <Object>[]}));
    await _pump(tester, off, flag: false);
    expect(off.asked, isEmpty);
    final seat = _Offers((_) async => RoomOfferView.fromJson({'currency': 'EUR', 'fees': <Object>[]}));
    await _pump(tester, seat, officeId: null);
    expect(seat.asked, isEmpty);
  });

  testWidgets('the whole-space price line keeps its key', (tester) async {
    final offers = _Offers((_) async => throw StateError('no'));
    await _pump(tester, offers, officeId: null, priceLine: '10.00 EUR / half day');
    expect(find.byKey(const ValueKey('space-price-line')), findsOneWidget);
    expect(find.text('10.00 EUR / half day'), findsOneWidget);
  });
}

// SPDX-License-Identifier: 0BSD
//
// #620 — occupant profile photos on the member-facing maps: the Plan
// tab and the Reserve hub draw the occupant's photo in the seat marker
// (the #618 kiosk mechanism, behind its own standalone flag).
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/plan/presentation/widgets/plan_canvas.dart';
import 'package:deskilo/features/plan/presentation/widgets/seat_photos.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

Future<Uint8List> _realPng(WidgetTester tester) async {
  final png = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
        .drawColor(const ui.Color(0xFF336699), ui.BlendMode.src);
    final image = await recorder.endRecording().toImage(4, 4);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  return png!;
}

Reservation _occupied() => Reservation(
      id: 'res-photo',
      workspaceId: 'ws-1',
      seatId: 'seat-4',
      memberId: 'member-1',
      startsAt: DateTime(kTestNow.year, kTestNow.month, kTestNow.day, 8),
      endsAt: DateTime(kTestNow.year, kTestNow.month, kTestNow.day, 17),
      status: ReservationStatus.checkedIn,
    );

Future<void> _pump(
  WidgetTester tester, {
  required FakeProfileRepository profile,
  Map<String, dynamic> featureFlags = const {},
}) async {
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  final reservations = FakeReservationRepository()
    ..reservations.add(_occupied());
  final workspace =
      FakeWorkspaceRepository.withWorkspace(featureFlags: featureFlags)
        ..memberNames = {'member-1': 'Flo'}
        ..openWeekdays['ws-1'] = const [1, 2, 3, 4, 5, 6, 7];
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        floorPlan: plans,
        reservations: reservations,
        workspace: workspace,
        profile: profile,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

FakeProfileRepository _photoProfile(Uint8List png) {
  final profile = FakeProfileRepository(profiles: [
    const Profile(
      id: 'user-1',
      displayName: 'Flo',
      avatarPath: 'user-1/avatar',
    ),
  ]);
  profile.avatarBytes['user-1'] = png;
  return profile;
}

void main() {
  testWidgets('#620 — the PLAN tab delivers the occupant photo to the '
      'painter', (tester) async {
    final png = await _realPng(tester);
    await _pump(tester, profile: _photoProfile(png));
    await switchToPlanTab(tester);
    await tester.pumpAndSettle();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    final canvas = tester.widget<PlanCanvas>(find.byType(PlanCanvas));
    expect(canvas.seatPhotos.keys, contains('seat-4'));
  });

  testWidgets('#620 — the RESERVE hub delivers it too; the flag OFF '
      'keeps every map on initials', (tester) async {
    final png = await _realPng(tester);
    await _pump(tester, profile: _photoProfile(png));
    // The app boots on the Reserve hub — its canvas is the first map.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    final canvas = tester.widget<PlanCanvas>(find.byType(PlanCanvas));
    expect(canvas.seatPhotos.keys, contains('seat-4'));
  });

  testWidgets('#620 — planMemberPhotos OFF keeps the loader empty',
      (tester) async {
    final png = await _realPng(tester);
    await _pump(
      tester,
      profile: _photoProfile(png),
      featureFlags: const {'planMemberPhotos': false},
    );
    final loader =
        tester.widget<SeatPhotoLoader>(find.byType(SeatPhotoLoader).first);
    expect(loader.seatUserIds, isEmpty);
    final canvas = tester.widget<PlanCanvas>(find.byType(PlanCanvas));
    expect(canvas.seatPhotos, isEmpty);
  });
}

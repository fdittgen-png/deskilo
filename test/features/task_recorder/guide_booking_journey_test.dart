// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1867 — the whole loop on the real app: a booking is recorded, the
// recording becomes a draft guide, the guide starts in the current scope
// and another person follows it on the REAL Reserve hub and booking sheet.
// Choosing the place completes its step; tapping Confirm only makes the
// confirm step wait; the booking command's real answer completes it.
// The guide books nothing itself: exactly one more create call, the one
// the person made. A refused booking keeps the step open and shows the
// recovery, with truthful progress.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_center_button.dart';
import 'package:deskilo/core/demo/data/reservation_repository.dart';
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:deskilo/features/task_recorder/data/recorder_store.dart';
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/guide/builtin_guides.dart';
import 'package:deskilo/features/task_recorder/guide/guide_codec.dart';
import 'package:deskilo/features/task_recorder/guide/guide_compiler.dart';
import 'package:deskilo/features/task_recorder/guide/guide_runner.dart';
import 'package:deskilo/features/task_recorder/guide/guide_session.dart';
import 'package:deskilo/features/task_recorder/providers/recorder_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';
import '../reservations/reserve_hub_test.dart' show seatCenter;
import 'fixtures/recording_fixtures.dart';

class _RefusingRepository extends FakeReservationRepository {
  @override
  Future<String> create({
    required String workspaceId,
    String? seatId,
    String? deskId,
    String? officeId,
    String? levelId,
    required DateTime startsAt,
    required DateTime endsAt,
    bool checkIn = false,
  }) async {
    createCalls++;
    throw const PostgrestException(message: 'overlap');
  }
}

Future<({ProviderContainer container, FakeReservationRepository repo})> _pump(
  WidgetTester tester, {
  FakeReservationRepository? repo,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final reservations = repo ?? FakeReservationRepository();
  final container = ProviderContainer(
    overrides: [
      ...standardTestOverrides(
        floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
        reservations: reservations,
        workspace: FakeWorkspaceRepository.withWorkspace()
          ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
          ..openWeekdays['ws-1'] = const [1, 2, 3, 4, 5, 6, 7],
      ),
      recorderStoreProvider.overrideWithValue(
        RecorderStore(
          backend: MemoryRecorderLogBackend(),
          namespace: canaryNamespace,
        ),
      ),
      recorderScopeProvider.overrideWithValue(canaryScope),
      taskRecorderAvailableProvider.overrideWith((ref) => true),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const DeskiloApp()),
  );
  await tester.pumpAndSettle();
  return (container: container, repo: reservations);
}

Future<void> _openReserve(WidgetTester tester) async {
  await tester.tap(find.byType(ShellCenterButton));
  await tester.pumpAndSettle();
}

Future<void> _chooseA1(WidgetTester tester) async {
  await tester.tapAt(seatCenter(tester));
  await tester.pumpAndSettle();
  expect(find.byType(BookingSheet), findsOneWidget);
}

GuideRun _run(ProviderContainer c) => c.read(guideSessionProvider).run!;

Future<void> _done(WidgetTester tester, ProviderContainer c) async {
  c.read(guideSessionProvider.notifier).close();
  await tester.pumpWidget(const SizedBox());
  c.dispose();
}

void main() {
  testWidgets('record → draft → start → follow on the real Reserve UI → the '
      'real answer completes the guide', (tester) async {
    // 1. Someone records booking a place.
    final author = await _pump(tester);
    final recorder = author.container.read(recorderControllerProvider);
    expect(await recorder.start(scope: canaryScope), isTrue);
    await _openReserve(tester);
    await _chooseA1(tester);
    await tester.tap(find.byKey(const ValueKey('booking-confirm')));
    await tester.pumpAndSettle();
    final recording = (await recorder.stop())!;
    expect(author.repo.createCalls, 1);
    await tester.pumpWidget(const SizedBox());
    author.container.dispose();

    // 2. The recording becomes a reviewed draft (codec round trip).
    final decoded = decodeGuideText(encodeGuideText(compileGuide(recording)));
    expect(decoded.runnable, isTrue);
    final guide = decoded.guide!;
    expect(
      guide.steps.map((s) => s.action),
      containsAllInOrder([
        RecorderActions.selectResource,
        RecorderActions.confirmBooking,
      ]),
    );

    // 3. Another session follows it, nothing recorded.
    final hub = await _pump(tester);
    final c = hub.container;
    expect(c.read(guideSessionProvider.notifier).start(guide), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('guide-host')), findsOneWidget);
    await _openReserve(tester);
    // Steps already true here (a view, a day) are skipped — skipped, not done.
    while (_run(c).current!.action != RecorderActions.selectResource) {
      await tester.tap(find.byKey(const ValueKey('guide-host-skip')));
      await tester.pumpAndSettle();
    }

    // 4. Choosing the place on the real plan completes its step.
    await _chooseA1(tester);
    expect(_run(c).current!.action, RecorderActions.confirmBooking);
    final confirmStep = _run(c).current!.id;
    expect(_run(c).statusOf(confirmStep), GuideStepStatus.pending);

    // 5. Confirm: the real answer completes it.
    await tester.tap(find.byKey(const ValueKey('booking-confirm')));
    await tester.pumpAndSettle();
    expect(_run(c).statusOf(confirmStep), GuideStepStatus.done);
    expect(_run(c).state, GuideRunState.completed);
    expect(find.byKey(const ValueKey('guide-host-completed')), findsOneWidget);
    // The guide booked nothing itself: one create, the person's own.
    expect(hub.repo.createCalls, 1);
    expect(hub.repo.reservations, hasLength(1));
    await _done(tester, c);
  });

  testWidgets('a refused booking keeps the step open and shows the recovery', (
    tester,
  ) async {
    final hub = await _pump(tester, repo: _RefusingRepository());
    final c = hub.container;
    expect(
      c
          .read(guideSessionProvider.notifier)
          .start(builtinGuide(null, BuiltinGuide.bookAPlace)),
      isTrue,
    );
    await tester.pumpAndSettle();
    // The introduction is acknowledged, never "verified".
    await tester.tap(find.byKey(const ValueKey('guide-host-done')));
    await tester.pumpAndSettle();
    expect(_run(c).statusOf('g1'), GuideStepStatus.acknowledged);
    await _openReserve(tester);
    while (_run(c).current!.action != RecorderActions.selectResource) {
      await tester.tap(find.byKey(const ValueKey('guide-host-skip')));
      await tester.pumpAndSettle();
    }
    await _chooseA1(tester);
    await tester.tap(find.byKey(const ValueKey('booking-confirm')));
    await tester.pumpAndSettle();

    expect(hub.repo.createCalls, 1);
    expect(_run(c).statusOf('g6'), GuideStepStatus.pending);
    expect(_run(c).current!.id, 'g6r1');
    expect(find.byKey(const ValueKey('guide-host-recovery')), findsOneWidget);
    expect(_run(c).state, GuideRunState.running);
    await _done(tester, c);
  });
}

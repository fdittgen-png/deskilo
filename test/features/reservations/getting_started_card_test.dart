// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1654 — the Get started card on the Reserve hub, driven through the
// real app: a joined member sees which workspace this is and ONE next
// step, every tap reaches the existing consumer (the hub's date picker,
// Settings, the help) and writes nothing on the way; a booking made
// through the existing sheet updates the card from the reservation the
// repository actually returned; a refusal keeps the context and ticks
// nothing; Not now stores exactly one scoped key and the next start
// shows no card, while another account on the same phone still gets
// its own; the flag OFF hides the card and leaves booking usable.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_center_button.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/demo/data/device_prefs.dart';
import 'package:deskilo/core/demo/data/floor_plan_repository.dart';
import 'package:deskilo/core/locale/locale_controller.dart';
import 'package:deskilo/core/storage/help_hint_store.dart';
import 'package:deskilo/features/help/presentation/screens/help_screen.dart';
import 'package:deskilo/features/help/providers/help_providers.dart';
import 'package:deskilo/features/profile/presentation/screens/settings_screen.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:visibility_detector/visibility_detector.dart';

import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';
import 'reserve_hub_test.dart' show seatCenter;

const _card = ValueKey('getting-started-card');
const _title = ValueKey('getting-started-title');
const _primary = ValueKey('getting-started-primary');
const _dismiss = ValueKey('getting-started-dismiss');
const _booking = ValueKey('getting-started-booking');

/// An ordinary member of ws-1: no role, no admin power.
const kOrdinaryMember = Member(
  id: 'member-1',
  workspaceId: 'ws-1',
  userId: 'user-1',
  isAdmin: false,
  isOwner: false,
  status: MemberStatus.active,
);

/// My membership cannot be read at all.
class _MembershipDown extends FakeWorkspaceRepository {
  _MembershipDown() : super.withWorkspace();
  @override
  Future<Member?> fetchMyMember(String workspaceId) async =>
      throw StateError('no connection');
}

/// The server refuses every booking.
class _RefusingReservations extends FakeReservationRepository {
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
    throw const PostgrestException(message: 'quota exhausted');
  }
}

typedef Hub = ({
  FakeReservationRepository reservations,
  FakeWorkspaceRepository workspace,
  InMemoryHelpHintStore hints,
});

/// The app, entered on the Reserve hub as [member] would see it.
Future<Hub> pumpCard(
  WidgetTester tester, {
  Member member = kOrdinaryMember,
  FakeWorkspaceRepository? workspace,
  FakeReservationRepository? reservations,
  FakeFloorPlanRepository? plans,
  InMemoryHelpHintStore? hints,
  Map<String, dynamic> featureFlags = const {},
  FakeAuthRepository? auth,
  // #1654 C3 — the structural and scoping cases.
  Size size = const Size(800, 1400),
  BackendSettingsStore? backendSettings,
  String? languageCode,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final plan = plans ?? (FakeFloorPlanRepository()..seedSmallPlan());
  final repo = reservations ?? FakeReservationRepository();
  final ws =
      workspace ??
      (FakeWorkspaceRepository.withWorkspace(featureFlags: featureFlags)
        ..myMember = member
        ..memberNames = {'member-1': 'Flo'}
        ..openWeekdays['ws-1'] = const [1, 2, 3, 4, 5, 6, 7]);
  final store = hints ?? InMemoryHelpHintStore();
  // #606 idiom — the help screen's visibility detector must not leave a
  // timer behind a test that navigates to it.
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  await tester.pumpWidget(
    ProviderScope(
      // A fresh container on every pump: without the key, a second pump
      // updates the SAME scope and its kept-alive providers, so "the next
      // start" would never re-read the store.
      key: UniqueKey(),
      overrides: [
        ...standardTestOverrides(
          floorPlan: plan,
          reservations: repo,
          workspace: ws,
          helpHints: store,
          auth: auth,
          backendSettings: backendSettings,
        ),
        if (languageCode != null)
          localeStoreProvider.overrideWithValue(
            InMemoryLocaleStore()..languageCode = languageCode,
          ),
        helpContentProvider.overrideWith(
          (ref, languageCode) async =>
              '# User Guide\n\n## 4. Reserve hub\n\nHi.\n',
        ),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byType(ShellCenterButton));
  await tester.pumpAndSettle();
  return (reservations: repo, workspace: ws, hints: store);
}

String _text(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data ?? '';

String _primaryLabel(WidgetTester tester) =>
    tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(_primary),
            matching: find.byType(Text),
          ),
        )
        .data ??
    '';

void main() {
  testWidgets('a joined member sees which workspace this is and ONE next '
      'step — and merely rendering writes nothing', (tester) async {
    final hub = await pumpCard(tester);
    expect(find.byKey(_card), findsOneWidget);
    expect(_text(tester, _title), 'Get started in Test Space');
    expect(_primaryLabel(tester), 'Choose a time to book');
    expect(find.textContaining('You are a member here.'), findsOneWidget);
    // One suggestion, not a wall of three.
    expect(find.text('View my membership'), findsNothing);
    expect(find.text('Help for this workspace'), findsNothing);
    expect(hub.reservations.createCalls, 0);
    expect(hub.hints.dismissed, isEmpty);
    expect(hub.workspace.flagWrites, isEmpty);
  });

  testWidgets("Choose a time opens the hub's own date picker and books "
      'nothing', (tester) async {
    final hub = await pumpCard(tester);
    await tester.tap(find.byKey(_primary));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(hub.reservations.createCalls, 0);
    expect(hub.reservations.reservations, isEmpty);
  });

  testWidgets('an empty plan suggests reading the membership — never '
      'creating seats — and the tap reaches Settings', (tester) async {
    final hub = await pumpCard(tester, plans: FakeFloorPlanRepository());
    expect(_primaryLabel(tester), 'View my membership');
    expect(find.textContaining('create'), findsNothing);
    expect(find.textContaining('draw'), findsNothing);
    await tester.tap(find.byKey(_primary));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(hub.reservations.createCalls, 0);
    expect(hub.hints.dismissed, isEmpty);
  });

  testWidgets('a membership that could not be loaded suggests the help, '
      'claims nothing about booking, and the tap reaches it', (tester) async {
    await pumpCard(tester, workspace: _MembershipDown());
    expect(_primaryLabel(tester), 'Help for this workspace');
    expect(find.textContaining('open on this day'), findsNothing);
    expect(find.textContaining('You may hold'), findsNothing);
    await tester.tap(find.byKey(_primary));
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsOneWidget);
  });

  testWidgets('one normal booking through the existing sheet: the card '
      'shows the real id and state the repository returned', (tester) async {
    final hub = await pumpCard(tester);
    expect(find.byKey(_booking), findsNothing);
    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    expect(find.byType(BookingSheet), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('booking-confirm')));
    await tester.pumpAndSettle();
    final made = hub.reservations.reservations.single;
    // The fake decides the state (a booking that starts now is a walk-up
    // check-in); the card shows whatever it decided, never a guess.
    final state = switch (made.status) {
      ReservationStatus.reserved => 'reserved',
      ReservationStatus.checkedIn => 'checked in',
      _ => fail('unexpected state ${made.status}'),
    };
    expect(_text(tester, _booking), '${made.id} · $state');
    expect(_primaryLabel(tester), 'View my membership');
    // The card said nothing about the booking until the repository did.
    expect(hub.reservations.createCalls, 1);
  });

  testWidgets('a backend refusal keeps the context and ticks nothing', (
    tester,
  ) async {
    final hub = await pumpCard(tester, reservations: _RefusingReservations());
    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-confirm')));
    await tester.pumpAndSettle();
    expect(hub.reservations.createCalls, 1);
    expect(hub.reservations.reservations, isEmpty);
    expect(_text(tester, _title), 'Get started in Test Space');
    expect(_primaryLabel(tester), 'Choose a time to book');
    expect(find.byKey(_booking), findsNothing);
  });

  testWidgets('Not now stores exactly one scoped key, the next start shows '
      'no card, and the view menu reopens it', (tester) async {
    final hub = await pumpCard(tester);
    await tester.tap(find.byKey(_dismiss));
    await tester.pumpAndSettle();
    expect(find.byKey(_card), findsNothing);
    final key = hub.hints.dismissed.single;
    expect(key, startsWith('getting-started:v1:'));
    expect(key, endsWith(':user-1:ws-1'));
    // Nothing else moved: no booking, no flag, no membership write.
    expect(hub.reservations.createCalls, 0);
    expect(hub.workspace.flagWrites, isEmpty);

    // A fresh start on the same phone, same account, same workspace.
    await pumpCard(tester, hints: hub.hints);
    expect(find.byKey(_card), findsNothing);

    // The view menu's Get started entry brings it back — and only it.
    hub.hints.dismissed.add('reserve');
    await pumpCard(tester, hints: hub.hints);
    await tester.tap(find.byKey(const ValueKey('reserve-view-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reserve-view-get-started')));
    await tester.pumpAndSettle();
    expect(find.byKey(_card), findsOneWidget);
    expect(hub.hints.dismissed, {'reserve'});
  });

  testWidgets('another account on the same phone still sees its own card', (
    tester,
  ) async {
    final hub = await pumpCard(tester);
    await tester.tap(find.byKey(_dismiss));
    await tester.pumpAndSettle();
    await pumpCard(
      tester,
      hints: hub.hints,
      auth: FakeAuthRepository(userId: 'user-2'),
      member: kOrdinaryMember.copyWith(id: 'member-2', userId: 'user-2'),
    );
    expect(find.byKey(_card), findsOneWidget);
    expect(hub.hints.dismissed, hasLength(1));
  });

  testWidgets('the flag OFF hides the card and changes nothing else: '
      'booking stays usable', (tester) async {
    await pumpCard(tester, featureFlags: {'memberGettingStarted': false});
    expect(find.byKey(_card), findsNothing);
    await tester.tap(find.byKey(const ValueKey('reserve-view-switch')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('reserve-view-get-started')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('reserve-view-plan')).last);
    await tester.pumpAndSettle();
    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    expect(find.byType(BookingSheet), findsOneWidget);
  });

  testWidgets('an owner who has set the space up gets the normal permitted '
      'task, not a setup tour', (tester) async {
    await pumpCard(
      tester,
      member: kOrdinaryMember.copyWith(isOwner: true, isAdmin: true),
    );
    expect(
      find.textContaining('You are an owner of this workspace.'),
      findsOneWidget,
    );
    expect(_primaryLabel(tester), 'Choose a time to book');
    expect(find.textContaining('tariff'), findsNothing);
    expect(find.textContaining('approval'), findsNothing);
  });
}

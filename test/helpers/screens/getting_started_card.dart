// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in getting_started_card_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_center_button.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/demo/data/device_prefs.dart';
import 'package:deskilo/core/demo/data/floor_plan_repository.dart';
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/core/links/link_launcher.dart';
import 'package:deskilo/core/locale/locale_controller.dart';
import 'package:deskilo/core/storage/help_hint_store.dart';
import 'package:deskilo/features/help/providers/help_providers.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../fake_reservation_repository.dart';
import '../mock_providers.dart';

/// An ordinary member of ws-1: no role, no admin power.
const kOrdinaryMember = Member(
  id: 'member-1',
  workspaceId: 'ws-1',
  userId: 'user-1',
  isAdmin: false,
  isOwner: false,
  status: MemberStatus.active,
);

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
  FakeLocalSetupRepository? localSetup,
  LinkLauncher? launcher,
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
          localSetup: localSetup,
        ),
        if (launcher != null) linkLauncherProvider.overrideWithValue(launcher),
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

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C4 — Privacy & data: under the personal shell the export of my
// data lives in My data › Personal information, one source at a time, so
// the legacy single-workspace share gives way to a link there. With the
// shell off, the legacy entry stays where it was.
import 'package:deskilo/features/profile/presentation/screens/privacy_screen.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _myData = '/me/data?view=profile';

Future<void> _pump(WidgetTester tester, {String? myDataPath}) async {
  final router = GoRouter(
    initialLocation: '/privacy',
    routes: [
      GoRoute(
        path: '/privacy',
        builder: (_, _) => PrivacyScreen(myDataPath: myDataPath),
      ),
      GoRoute(
        path: '/me/data',
        builder: (_, state) => Scaffold(
          body: Text(
            'my-data:${state.uri.queryParameters['view']}',
            key: const ValueKey('my-data-landed'),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await pumpApp(
    tester,
    null,
    router: router,
    size: const Size(800, 1400),
    overrides: [
      ...standardTestOverrides(auth: FakeAuthRepository.signedIn()),
      enabledFeaturesSyncProvider.overrideWithValue({
        WorkspaceFeature.memberDataExport,
      }),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('with the personal shell, the export is a link to My data '
      '› Personal information', (tester) async {
    await _pump(tester, myDataPath: _myData);
    expect(find.byKey(const ValueKey('privacy-export')), findsNothing);
    final link = find.byKey(const ValueKey('privacy-export-my-data'));
    expect(link, findsOneWidget);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('my-data:profile'), findsOneWidget);
  });

  testWidgets('without it, the legacy export entry stays', (tester) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('privacy-export')), findsOneWidget);
    expect(find.byKey(const ValueKey('privacy-export-my-data')), findsNothing);
  });
}

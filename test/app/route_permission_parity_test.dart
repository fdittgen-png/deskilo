// SPDX-License-Identifier: 0BSD
//
// #1085 — `myPermissions` documents the rule: "The one client-side gate:
// screens ask for a permission, never for a role flag." The Settings
// tiles were migrated to it; the routes behind them were not, and still
// redirected on `actsAsOwner`.
//
// `defaultPermissionsFor(admin)` already contains `manageServices` and
// `operateKiosk`, so OUT OF THE BOX an ordinary admin sees "Services"
// and "RFID / NFC badges", taps one, and is silently bounced to
// /messages — with no explanation, because a redirect is not a refusal.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/mock_providers.dart';

/// Boots as a non-owner admin and pushes [route], returning the location
/// the router actually settled on.
Future<String> locationAfterPush(
  WidgetTester tester,
  String route, {
  Map<String, bool> features = const {},
}) async {
  final workspace = FakeWorkspaceRepository.withWorkspace(
    featureFlags: {'calendarHub': false, ...features},
  )..myMember = const Member(
      id: 'member-1',
      workspaceId: 'ws-1',
      userId: 'user-1',
      isAdmin: true,
      isOwner: false,
      status: MemberStatus.active,
    );
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  final router = GoRouter.of(context);
  router.push(route);
  await tester.pumpAndSettle();
  return router.state.uri.toString();
}

void main() {
  // Route → the permission its Settings tile already asks for. An admin
  // holds every one of these by default, or is shown the tile because a
  // role grants it; either way the door must agree with the sign on it.
  const cases = <String, Map<String, bool>>{
    '/services': {'services': true},
    '/nfc-config': {'nfcBadges': true},
  };

  for (final entry in cases.entries) {
    testWidgets('an admin shown ${entry.key} can actually open it',
        (tester) async {
      final landed = await locationAfterPush(
        tester,
        entry.key,
        features: entry.value,
      );
      expect(landed, entry.key,
          reason: 'the tile is offered on an admin default permission, so '
              'the route must not bounce to ${landed == "/messages" ? "/messages" : landed}');
    });
  }
}

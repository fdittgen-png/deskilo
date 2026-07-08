// SPDX-License-Identifier: MIT
//
// App-start validation per role (#87): the app must reach the shell for
// every role defined on the workspace membership (owner / admin / worker),
// showing exactly the affordances that role grants (spec §2).
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';

Member member({required bool isAdmin, required bool isOwner}) => Member(
      id: 'member-1',
      workspaceId: 'ws-1',
      userId: 'user-1',
      isAdmin: isAdmin,
      isOwner: isOwner,
      status: MemberStatus.active,
    );

Future<void> bootAs(
  WidgetTester tester, {
  required bool isAdmin,
  required bool isOwner,
}) async {
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..myMember = member(isAdmin: isAdmin, isOwner: isOwner);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('owner boots into the shell with editor and members access',
      (tester) async {
    await bootAs(tester, isAdmin: true, isOwner: true);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byIcon(Icons.design_services_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Members & plans'), findsOneWidget);
  });

  testWidgets(
      'admin boots into the shell with everyone-calendar but no editor',
      (tester) async {
    await bootAs(tester, isAdmin: true, isOwner: false);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byIcon(Icons.design_services_outlined), findsNothing);

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Everyone'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Members & plans'), findsNothing);
  });

  testWidgets('worker boots into the shell with neither admin affordance',
      (tester) async {
    await bootAs(tester, isAdmin: false, isOwner: false);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byIcon(Icons.design_services_outlined), findsNothing);

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Everyone'), findsNothing);
  });
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1864 C — the validation rules screen pump, moved out of `test/features/events/validation_settings_screen_test.dart`:
// the accessibility matrix, the locale walk and the other suites that
// reuse it import this helper instead of a whole test file.
import 'dart:async';
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/events/domain/validation_policy.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import '../fake_event_repository.dart';
import '../mock_providers.dart';

Member admin(String id) => Member(
      id: id,
      workspaceId: 'ws-1',
      userId: 'user-$id',
      isAdmin: true,
      isOwner: false,
      status: MemberStatus.active,
    );

/// Seed the fakes BEFORE pumping — the providers cache their first read.
/// The default workspace has owner member-1 (Flo) plus admins Ana and Bo.
Future<FakeEventRepository> pumpValidationSettings(
  WidgetTester tester, {
  List<ValidationPolicy> policies = const [],
  List<Member>? otherMembers,
  Map<String, dynamic> featureFlags = const {},
  // #1339 — the responsive matrix asks for a narrow surface. Every
  // other caller keeps the tall one this file has always used, so
  // nothing existing changes.
  Size size = const Size(1200, 3400),
}) async {
  final events = FakeEventRepository()..policies.addAll(policies);
  // Policy cards (0097 added Booking deletion) outgrow the default
  // 600px fold; a taller surface keeps every card built and hit-testable.
  // 3100 → 3400 (#1235): each card's title carries a help symbol, and
  // the symbol went from 40 dp to the 48 dp floor, so the stack of 24
  // grew past the old surface and the last card stopped being built.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final workspace = FakeWorkspaceRepository.withWorkspace(
      featureFlags: featureFlags)
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana', 'member-3': 'Bo'}
    ..otherMembers
        .addAll(otherMembers ?? [admin('member-2'), admin('member-3')]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(events: events, workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  unawaited(GoRouter.of(context).push('/validation'));
  await tester.pumpAndSettle();
  return events;
}

// #881 — the payment_terms_change card joins the list: 18 cards, 17
// inheriting the default.

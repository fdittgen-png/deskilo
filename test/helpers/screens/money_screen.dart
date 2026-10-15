// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in money_screen_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'package:deskilo/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_event_repository.dart';
import '../fake_money_repository.dart';
import '../mock_providers.dart';

Future<FakeMoneyRepository> pumpMoney(
  WidgetTester tester, {
  FakeMoneyRepository? money,
  FakeEventRepository? events,
  FakeWorkspaceRepository? workspace,
}) async {
  // Portrait viewport (#284 idiom): the 800×600 default is LANDSCAPE and
  // would engage the money split; feature tests exercise the column.
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  money ??= FakeMoneyRepository();
  // #720 — these tests exercise the CLASSIC column (every card and
  // button on one page); the faces have their own file.
  workspace ??= FakeWorkspaceRepository.withWorkspace();
  final ws = workspace.workspaces.first;
  workspace.workspaces[0] = ws.copyWith(
    featureFlags: {...ws.featureFlags, 'financeFaces': false},
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        money: money,
        events: events,
        workspace: workspace,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Money'));
  await tester.pumpAndSettle();
  return money;
}

/// A workspace whose owner configured how-to-pay details (#155, #192).
FakeWorkspaceRepository workspaceWithInstructions() {
  final workspace = FakeWorkspaceRepository.withWorkspace();
  workspace.workspaces[0] = workspace.workspaces[0].copyWith(
    paymentInstructions: const {
      'iban': 'DE89 3704 0044 0532 0130 00',
      'paypal_me': 'deskilo',
      'reference': 'DesKilo member period',
      'wero': '+49 170 0000000',
      'lydia': '+33 6 00 00 00 00',
      'wise': '@deskilo',
    },
  );
  return workspace;
}

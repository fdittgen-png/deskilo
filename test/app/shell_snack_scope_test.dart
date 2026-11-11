// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3286 — a snack (with or without its action) raised in one context is
// gone once the person changes business, account or persona; the same
// context again clears nothing.
import 'dart:async';

import 'package:deskilo/app/shell/snack_scope.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_session.dart';
import 'package:deskilo/core/session/session_source.dart';
import 'package:deskilo/core/ui/app_snack.dart';
import 'package:deskilo/features/workspace/providers/active_workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Workspace extends ActiveWorkspaceId {
  @override
  Future<String?> build() async => 'ws-a';

  void pick(String id) => state = AsyncData(id);
}

class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchSnackScope(ref);
    return Scaffold(
      body: TextButton(
        onPressed: () => AppSnack.info(
          context,
          'Booked',
          action: SnackBarAction(label: 'Details', onPressed: () {}),
        ),
        child: const Text('show'),
      ),
    );
  }
}

void main() {
  late StreamController<String?> session;
  late _Workspace workspace;
  late ProviderContainer container;

  Future<void> pumpHost(WidgetTester tester) async {
    session = StreamController<String?>.broadcast();
    workspace = _Workspace();
    container = ProviderContainer(
      overrides: [
        sessionStateProvider.overrideWith((ref) => session.stream),
        activeWorkspaceIdProvider.overrideWith(() => workspace),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: _Host()),
      ),
    );
    session.add('user-1');
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Booked'), findsOneWidget);
  }

  tearDown(() async {
    container.dispose();
    await session.close();
  });

  testWidgets('changing workspace clears the snack and its action', (
    tester,
  ) async {
    await pumpHost(tester);
    workspace.pick('ws-b');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Booked'), findsNothing);
    expect(find.text('Details'), findsNothing);
  });

  testWidgets('changing account clears the snack', (tester) async {
    await pumpHost(tester);
    session.add('user-2');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Booked'), findsNothing);
  });

  testWidgets('changing persona clears the snack', (tester) async {
    await pumpHost(tester);
    container
        .read(demoSessionControllerProvider.notifier)
        .viewAs(DemoPersona.admin);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Booked'), findsNothing);
  });

  testWidgets('the same context again keeps the snack', (tester) async {
    await pumpHost(tester);
    session.add('user-1');
    await tester.pump();
    expect(find.text('Booked'), findsOneWidget);
  });
}

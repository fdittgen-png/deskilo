// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4018 — a full-screen dialog's own messenger (the invoicing pages, the
// bank statements) goes with the context like the app's: a notice with an
// action raised there is gone once the person changes business or account,
// and kept while nothing changes. No timeout is touched.
import 'dart:async';

import 'package:deskilo/app/shell/snack_scope.dart';
import 'package:deskilo/core/session/session_source.dart';
import 'package:deskilo/core/ui/app_snack.dart';
import 'package:deskilo/core/ui/scoped_messenger.dart';
import 'package:deskilo/features/workspace/providers/active_workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Workspace extends ActiveWorkspaceId {
  @override
  Future<String?> build() async => 'ws-a';

  void pick(String id) => state = AsyncData(id);
}

/// The shell, with a full-screen dialog of its own messenger open over it.
class _Shell extends ConsumerWidget {
  const _Shell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchSnackScope(ref);
    return Scaffold(
      body: TextButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => Dialog.fullscreen(
            child: ScopedMessenger(
              child: Scaffold(
                body: Builder(
                  builder: (inner) => TextButton(
                    onPressed: () => AppSnack.info(
                      inner,
                      'Invoice sent',
                      action: SnackBarAction(label: 'Open', onPressed: () {}),
                    ),
                    child: const Text('notice'),
                  ),
                ),
              ),
            ),
          ),
        ),
        child: const Text('open'),
      ),
    );
  }
}

void main() {
  late StreamController<String?> session;
  late _Workspace workspace;

  Future<void> pumpDialog(WidgetTester tester) async {
    session = StreamController<String?>.broadcast();
    addTearDown(session.close);
    workspace = _Workspace();
    final container = ProviderContainer(
      overrides: [
        sessionStateProvider.overrideWith((ref) => session.stream),
        activeWorkspaceIdProvider.overrideWith(() => workspace),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: _Shell()),
      ),
    );
    session.add('user-1');
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('notice'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Invoice sent'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
  }

  testWidgets('another business clears the dialog\'s notice and its action', (
    tester,
  ) async {
    await pumpDialog(tester);
    workspace.pick('ws-b');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Invoice sent'), findsNothing);
    expect(find.text('Open'), findsNothing);
  });

  testWidgets('another account clears the dialog\'s notice', (tester) async {
    await pumpDialog(tester);
    session.add('user-2');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Invoice sent'), findsNothing);
  });

  testWidgets('the same context keeps the notice', (tester) async {
    await pumpDialog(tester);
    session.add('user-1');
    await tester.pump();
    expect(find.text('Invoice sent'), findsOneWidget);
  });
}

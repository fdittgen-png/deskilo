// SPDX-License-Identifier: 0BSD
//
// #1373 / #1375 — the Demo scope reaches the providers the SCREENS read,
// not only the ones the overrides name.
//
// `demo_scope_test` proves the list of overrides is complete. That is a
// different question from this one, and the difference cost a rewrite: a
// nested `ProviderScope` override reaches a provider read directly below
// it, and does not reach a provider that DEPENDS on the overridden one,
// because the dependent is hosted by the root container where nothing was
// overridden. `myWorkspacesProvider` depends on the workspace repository
// and on auth; inside a nested scope it answered from the live container
// and returned an empty list — a demo that silently shows nothing.
//
// `DemoWorkspace` therefore mounts its own root container. This test is
// the reason it must stay that way: it reads a DEPENDENT provider, the
// way a real screen does, and expects the fixture.
import 'package:deskilo/core/demo/presentation/demo_workspace.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A screen, in the only sense that matters here: it reads a provider
/// built on top of a repository rather than the repository itself.
class _Probe extends ConsumerWidget {
  const _Probe();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Text(
        ref.watch(myWorkspacesProvider).when(
              data: (list) =>
                  list.isEmpty ? 'none' : list.map((w) => w.name).join(','),
              error: (e, _) => 'error',
              loading: () => 'loading',
            ),
        textDirection: TextDirection.ltr,
      );
}

void main() {
  testWidgets('a provider that depends on an overridden one still resolves '
      'to the fixture', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DemoWorkspace(child: _Probe())),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Test Space'),
      findsOneWidget,
      reason: 'the demo workspace came from the fixture. "none" means the '
          'provider was hosted outside the Demo container and answered '
          'from the live one — the failure a nested ProviderScope had.',
    );
  });
}

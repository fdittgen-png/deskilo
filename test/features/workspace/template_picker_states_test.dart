// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1660 — a template request that is still out, or that failed, is not an
// empty library: the picker says which it is, a retry asks again, and a
// failure never leaves "Empty space" as the only choice on offer.
import 'dart:async';

import 'package:deskilo/features/workspace/domain/workspace_template.dart';
import 'package:deskilo/features/workspace/presentation/widgets/template_picker.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

/// Answers each templates request from [answers], in order.
class _ScriptedWorkspace extends FakeWorkspaceRepository {
  _ScriptedWorkspace(this.answers);
  final List<Future<List<WorkspaceTemplate>> Function()> answers;
  int calls = 0;

  @override
  Future<List<WorkspaceTemplate>> fetchWorkspaceTemplates() =>
      answers[calls++]();
}

Future<void> _pump(WidgetTester tester, FakeWorkspaceRepository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      // The app's own automatic retry would answer before the person
      // does; this test is about what a failure looks like.
      retry: (_, _) => null,
      overrides: standardTestOverrides(workspace: repo),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TemplatePicker(selectedId: null, onChanged: (_) {}),
          ),
        ),
      ),
    ),
  );
}

void main() {
  const tiny = WorkspaceTemplate(id: 'tpl-tiny', key: 'tiny', name: 'Tiny');

  testWidgets('still loading: a spinner, not an empty library', (tester) async {
    final pending = Completer<List<WorkspaceTemplate>>();
    await _pump(tester, _ScriptedWorkspace([() => pending.future]));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('template-picker-loading')),
      findsOneWidget,
    );
    expect(find.text('Empty space'), findsNothing);
    pending.complete(const [tiny]);
    await tester.pumpAndSettle();
    expect(find.text('Tiny'), findsOneWidget);
  });

  testWidgets('a failure says so, offers no empty space, and a retry asks '
      'again', (tester) async {
    final repo = _ScriptedWorkspace([
      () async => throw Exception('offline'),
      () async => const [tiny],
    ]);
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('template-picker-failed')),
      findsOneWidget,
    );
    expect(find.text('The templates could not be loaded.'), findsOneWidget);
    expect(
      find.text('Empty space'),
      findsNothing,
      reason: 'a failed request must not look like an empty library',
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('template-picker-failed')),
        matching: find.byType(TextButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
    expect(find.byKey(const ValueKey('template-picker-failed')), findsNothing);
    expect(find.text('Tiny'), findsOneWidget);
    expect(find.text('Empty space'), findsOneWidget);
  });
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2911 — the app's router re-asks the redirect whenever a membership, a
// feature flag or the session changes. A refresh that leaves the person
// where they are keeps the pushed page AND its answer: the caller awaiting
// `push` resumes when the page closes, by the router's pop or by Back.
import 'dart:async';

import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/router_paths.dart';

/// The answer of [push], read without awaiting a future that may never
/// come: [answered] says whether it came.
class _Answer {
  _Answer(Future<String?> push) {
    unawaited(
      push.then((value) {
        answered = true;
        this.value = value;
      }),
    );
  }

  bool answered = false;
  String? value;
}

void main() {
  testWidgets('a feature flag refresh while a page is pushed: the router '
      'pop still answers the push', (tester) async {
    final app = await bootRouter(tester);
    final container = ProviderScope.containerOf(app.context);
    final answer = _Answer(app.router.push<String>('/help'));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, '/help');

    container.invalidate(enabledFeaturesProvider);
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, '/help', reason: 'still pushed');
    expect(answer.answered, isFalse);

    app.router.pop('kept');
    await tester.pumpAndSettle();
    expect(answer.answered, isTrue);
    expect(answer.value, 'kept');
    expect(app.router.state.uri.path, '/reserve');
  });

  testWidgets('a membership refresh, twice, while a page is pushed: Back '
      'still answers the push', (tester) async {
    final app = await bootRouter(tester);
    final container = ProviderScope.containerOf(app.context);
    final answer = _Answer(app.router.push<String>('/help'));
    await tester.pumpAndSettle();

    for (var refresh = 0; refresh < 2; refresh++) {
      container
        ..invalidate(myMemberProvider)
        ..invalidate(myWorkspacesProvider);
      await tester.pumpAndSettle();
    }
    expect(app.router.state.uri.path, '/help');

    await tester.tap(find.byType(BackButton).hitTestable());
    await tester.pumpAndSettle();
    expect(answer.answered, isTrue);
    expect(answer.value, isNull);
    expect(app.router.state.uri.path, '/reserve');
  });
}

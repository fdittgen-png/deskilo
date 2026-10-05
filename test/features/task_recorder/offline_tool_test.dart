// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1886 — the offline local tool: on a native build there is nothing to
// keep (the card is absent); in a browser the card says only what the
// browser reports — kept, not kept, impossible here, refused — and keeps
// or stops keeping the workbench on the person's request, never by
// itself. The service worker never touches a write or another origin.
import 'dart:async';
import 'dart:io';

import 'package:deskilo/features/task_recorder/offline/offline_card.dart';
import 'package:deskilo/features/task_recorder/offline/offline_tool.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTool implements OfflineTool {
  _FakeTool(this._state);
  OfflineToolState _state;
  Completer<void>? pendingKeep;
  int keeps = 0;
  int forgets = 0;

  @override
  Future<OfflineToolState> state() async => _state;
  @override
  Future<OfflineToolState> keep() async {
    keeps++;
    await pendingKeep?.future;
    return _state = OfflineToolState.ready;
  }

  @override
  Future<OfflineToolState> forget() async {
    forgets++;
    return _state = OfflineToolState.off;
  }
}

Future<void> _pump(WidgetTester tester, OfflineTool tool) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [offlineToolProvider.overrideWithValue(tool)],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: OfflineToolCard()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('a native build has nothing to keep', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      await container.read(offlineToolProvider).state(),
      OfflineToolState.notNeeded,
    );
  });

  testWidgets('native: no card at all', (tester) async {
    await _pump(tester, _FakeTool(OfflineToolState.notNeeded));
    expect(find.byKey(const ValueKey('workbench-offline')), findsNothing);
  });

  testWidgets('browser: off, kept on request, then stopped', (tester) async {
    final tool = _FakeTool(OfflineToolState.off);
    await _pump(tester, tool);
    expect(find.textContaining('Not kept'), findsOneWidget);
    expect(tool.keeps, 0, reason: 'never kept by itself');
    await tester.tap(find.byKey(const ValueKey('workbench-offline-keep')));
    await tester.pumpAndSettle();
    expect(tool.keeps, 1);
    expect(find.textContaining('Kept on this browser'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('workbench-offline-forget')));
    await tester.pumpAndSettle();
    expect(tool.forgets, 1);
    expect(find.textContaining('Not kept'), findsOneWidget);
  });

  testWidgets('keeping the complete snapshot shows progress until verified', (tester) async {
    final tool = _FakeTool(OfflineToolState.off)..pendingKeep = Completer<void>();
    await _pump(tester, tool);
    await tester.tap(find.byKey(const ValueKey('workbench-offline-keep')));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('Kept on this browser'), findsNothing);
    tool.pendingKeep!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('Kept on this browser'), findsOneWidget);
  });

  testWidgets('a browser that cannot keep it says so, with no button', (
    tester,
  ) async {
    await _pump(tester, _FakeTool(OfflineToolState.unsupported));
    expect(find.textContaining('cannot keep it'), findsOneWidget);
    expect(find.byKey(const ValueKey('workbench-offline-keep')), findsNothing);
  });

  test('the service worker only reads this app\'s own files', () {
    final sw = File('web/task_tool_sw.js').readAsStringSync();
    expect(sw, contains("if (request.method !== 'GET') return;"));
    expect(
      sw,
      contains('if (!url.href.startsWith(self.registration.scope)) return;'),
    );
    expect(sw, isNot(contains('supabase')));
    expect(
      sw,
      contains('fetch(request)'),
      reason: 'network first: online behaves as without the worker',
    );
  });

  test('the installed app offers the workbench as a shortcut', () {
    final manifest = File('web/manifest.json').readAsStringSync();
    expect(manifest, contains('"url": "./#/task-workbench"'));
  });
}

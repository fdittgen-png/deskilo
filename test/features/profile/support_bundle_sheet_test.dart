// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1642 — "Prepare support details" from Settings: the preview is the
// exact text Save writes, a message logged with a canary never reaches
// either, Cancel writes nothing, and the flag OFF hides the entry.
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

const _tile = ValueKey('settings-support-bundle');
const _preview = ValueKey('support-bundle-preview');

Future<List<({Uint8List bytes, String fileName})>> _pump(
  WidgetTester tester, {
  Map<String, dynamic> featureFlags = const {},
}) async {
  tester.view.physicalSize = const Size(800, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final saved = <({Uint8List bytes, String fileName})>[];
  final workspace =
      FakeWorkspaceRepository.withWorkspace(featureFlags: featureFlags)
        ..myMember = const Member(
          id: 'member-1',
          workspaceId: 'ws-1',
          userId: 'user-1',
          isAdmin: true,
          isOwner: true,
          status: MemberStatus.active,
        );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(workspace: workspace),
        fileSaverProvider.overrideWithValue(({
          required Uint8List bytes,
          required String fileName,
        }) async {
          saved.add((bytes: bytes, fileName: fileName));
          return fileName;
        }),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  return saved;
}

String _previewText(WidgetTester tester) =>
    tester.widget<SelectableText>(find.byKey(_preview)).data ?? '';

void main() {
  setUp(() {
    TraceLogger.instance = TraceLogger();
    TraceLogger.instance.error(
      'money',
      'failed for canary.person@example.org',
      error: 'token=CANARY-SECRET',
    );
  });

  testWidgets('the preview is exactly what Save writes, and holds no canary', (
    tester,
  ) async {
    final saved = await _pump(tester);
    await tester.ensureVisible(find.byKey(_tile));
    await tester.tap(find.byKey(_tile));
    await tester.pumpAndSettle();
    final text = _previewText(tester);
    expect(text, contains('"bundle_version": 1'));
    expect(text, isNot(contains('CANARY')));
    expect(text, isNot(contains('example.org')));
    expect(text, contains('"backend": "omitted"'));
    await tester.tap(find.byKey(const ValueKey('support-bundle-save')));
    await tester.pumpAndSettle();
    expect(saved, hasLength(1));
    expect(utf8.decode(saved.single.bytes), text);
    expect(saved.single.fileName, startsWith('deskilo-support-'));
    expect(
      find.text('Saved on this device. Nothing was sent.'),
      findsOneWidget,
    );
  });

  testWidgets('including the server changes only that field; Cancel saves '
      'nothing', (tester) async {
    final saved = await _pump(tester);
    await tester.ensureVisible(find.byKey(_tile));
    await tester.tap(find.byKey(_tile));
    await tester.pumpAndSettle();
    final before = _previewText(tester);
    await tester.tap(find.byKey(const ValueKey('support-include-backend')));
    await tester.pumpAndSettle();
    final after = _previewText(tester);
    expect(after, isNot(contains('"backend": "omitted"')));
    final a = jsonDecode(before) as Map<String, Object?>;
    final b = jsonDecode(after) as Map<String, Object?>;
    expect({...a, 'context': null}, {...b, 'context': null});
    await tester.tap(find.byKey(const ValueKey('support-bundle-cancel')));
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
    expect(find.byKey(const ValueKey('support-bundle-sheet')), findsNothing);
  });

  testWidgets('the flag OFF hides the entry', (tester) async {
    await _pump(tester, featureFlags: const {'supportBundle': false});
    expect(find.byKey(_tile), findsNothing);
    expect(find.byKey(const ValueKey('settings-help')), findsOneWidget);
  });
}

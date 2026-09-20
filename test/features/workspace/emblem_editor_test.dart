// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1289 — the emblem on screen: absent changes nothing, chosen is
// stored re-drawn, removed is gone.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:deskilo/core/files/file_picker.dart';
import 'package:deskilo/features/workspace/presentation/screens/colours_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/real_async.dart';

import '../../helpers/mock_providers.dart';

Future<Uint8List> _png(int size) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    ui.Paint()..color = const Color(0xFF1F3A5F),
  );
  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<FakeWorkspaceRepository> _pump(
  WidgetTester tester, {
  Uint8List? picked,
  Uint8List? existing,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final workspace = FakeWorkspaceRepository.withWorkspace(
    featureFlags: const {'workspaceBranding': true},
  );
  if (existing != null) workspace.emblems['ws-1'] = existing;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(workspace: workspace),
        filePickerProvider.overrideWithValue(
          (group) async => picked == null
              ? null
              : XFile.fromData(picked, name: 'mark.png', mimeType: 'image/png'),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ColoursScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return workspace;
}

void main() {
  testWidgets('no emblem: the section offers one and there is nothing to '
      'remove', (tester) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('emblem-hint')), findsOneWidget);
    final remove =
        tester.widget<TextButton>(find.byKey(const ValueKey('emblem-remove')));
    expect(remove.onPressed, isNull);
  });

  testWidgets('a chosen file is stored re-drawn, not as it arrived',
      (tester) async {
    late Uint8List source;
    await tester.runAsync(() async => source = await _png(900));
    final workspace = await _pump(tester, picked: source);

    // The re-draw goes through the engine's codec, which does not run
    // under fake async — the seat-photo lesson again (#618).
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('emblem-pick')));
      await tester.pump();
      // Poll the observable result, never a fixed delay (#1334): the
      // codec takes as long as the machine takes.
      await untilReal(
        () => workspace.emblems['ws-1'] != null,
        what: 'the emblem was decoded, re-drawn and stored',
      );
    });
    await tester.pumpAndSettle();

    final stored = workspace.emblems['ws-1'];
    expect(stored, isNotNull);
    expect(stored, isNot(source),
        reason: 'the file is decoded and re-encoded, never passed through');
    expect(stored!.sublist(1, 4), 'PNG'.codeUnits);
  });

  testWidgets('removing an emblem leaves the space with none', (tester) async {
    late Uint8List stored;
    await tester.runAsync(() async => stored = await _png(128));
    final workspace = await _pump(tester, existing: stored);

    await tester.tap(find.byKey(const ValueKey('emblem-remove')));
    await tester.pumpAndSettle();

    expect(workspace.emblems.containsKey('ws-1'), isFalse);
  });
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3621 — a Windows or macOS program has no camera scanner: the scan sheets
// say so in one line, in the program's words (not the browser's), and the
// typed code stays the way in. A phone keeps its scanner.
import 'package:deskilo/core/scan/qr_scan_widget.dart';
import 'package:deskilo/features/reservations/presentation/widgets/space_scan_sheet.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SpaceScanSheet(
          workspaceId: 'ws-1',
          scanBuilder: null,
          l10n: AppLocalizationsEn(),
          explainNoCamera: !qrScanSupported,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Runs [body] as [platform]; the override is undone before the test ends
/// (the binding checks it before any tear-down).
Future<void> _as(TargetPlatform platform, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  final words = AppLocalizationsEn();
  const line = ValueKey('space-scan-no-camera');

  for (final platform in [TargetPlatform.windows, TargetPlatform.macOS]) {
    testWidgets('$platform: no scanner, said in the program\'s words, typed '
        'code offered', (tester) async {
      await _as(platform, () async {
        expect(qrScanSupported, isFalse);
        await _pumpSheet(tester);
        expect(find.byKey(line), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(line)).data,
          words.scanCameraProgramUnavailable,
        );
        expect(find.textContaining('browser'), findsNothing);
        expect(find.byType(TextField), findsWidgets);
      });
    });
  }

  testWidgets('a phone keeps its scanner and shows no such line', (
    tester,
  ) async {
    await _as(TargetPlatform.android, () async {
      expect(qrScanSupported, isTrue);
      await _pumpSheet(tester);
      expect(find.byKey(line), findsNothing);
    });
  });
}

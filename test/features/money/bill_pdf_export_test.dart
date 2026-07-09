// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/share/share_launcher.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

import '../../helpers/mock_providers.dart';

Future<void> pumpMoney(
  WidgetTester tester, {
  required ShareLauncher launcher,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(),
        shareLauncherProvider.overrideWithValue(launcher),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Money'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'the export button renders the visible bill as a PDF and hands it '
      'to the share sheet (#133)', (tester) async {
    final captured = <ShareParams>[];
    await pumpMoney(tester, launcher: (params) async => captured.add(params));

    final button = find.byIcon(Icons.picture_as_pdf_outlined);
    expect(button, findsOneWidget);

    // Font assets and PDF assembly need real async to complete.
    await tester.runAsync(() async {
      await tester.tap(button);
      await tester.pump();
    });
    await tester.pumpAndSettle();

    expect(captured, hasLength(1));
    expect(
      captured.single.fileNameOverrides,
      ['deskilo-bill-${currentPeriod()}.pdf'],
    );
    final file = captured.single.files!.single;
    expect(file.mimeType, 'application/pdf');
    final bytes = await tester.runAsync(() => file.readAsBytes());
    expect(String.fromCharCodes(bytes!.sublist(0, 5)), '%PDF-');
  });

  testWidgets('a failing share shows the generic error snackbar',
      (tester) async {
    await pumpMoney(
      tester,
      launcher: (params) async => throw Exception('no share target'),
    );

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.picture_as_pdf_outlined));
      await tester.pump();
    });
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });
}

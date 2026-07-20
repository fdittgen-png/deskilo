// SPDX-License-Identifier: MIT
import 'dart:typed_data';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<void> pumpMoney(
  WidgetTester tester, {
  required FileSaver saver,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(),
        fileSaverProvider.overrideWithValue(saver),
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
      'the export button renders the visible bill as a PDF saved locally '
      '(#133, not shared)', (tester) async {
    final saved = <(String, Uint8List)>[];
    await pumpMoney(
      tester,
      saver: ({required bytes, required fileName}) async {
        saved.add((fileName, bytes));
        return '/local/$fileName';
      },
    );

    final button = find.byIcon(Icons.picture_as_pdf_outlined);
    expect(button, findsOneWidget);

    // Font assets and PDF assembly need real async to complete.
    await tester.runAsync(() async {
      await tester.tap(button);
      await tester.pump();
    });
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(saved.single.$1, 'deskilo-bill-${currentPeriod()}.pdf');
    // A real PDF was written locally — no share sheet.
    expect(String.fromCharCodes(saved.single.$2.sublist(0, 5)), '%PDF-');
    expect(find.textContaining('/local/deskilo-bill-'), findsOneWidget);
  });

  testWidgets('a failing save shows the generic error snackbar',
      (tester) async {
    await pumpMoney(
      tester,
      saver: ({required bytes, required fileName}) async =>
          throw Exception('disk full'),
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

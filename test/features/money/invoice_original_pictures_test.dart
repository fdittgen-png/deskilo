// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3984 — an invoice whose design has a header and a footer picture, each
// added at 4000 x 3000, is kept as its original and weighs under 1 MB: the
// pictures were brought to print size when they were added. An original
// refused for its weight points to the picture library.
import 'dart:typed_data';

import 'package:deskilo/core/demo/data/money/demo_invoice_original_repository.dart';
import 'package:deskilo/core/images/report_picture_bytes.dart';
import 'package:deskilo/features/money/application/invoice_originals.dart';
import 'package:deskilo/features/money/domain/invoice_original.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/presentation/document_policies.dart';
import 'package:deskilo/features/money/presentation/invoice_original_document.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/real_async.dart';
import '../../helpers/test_workspace_context.dart';

/// A 4000 x 3000 picture made here, as a PNG without transparency.
Uint8List _large() {
  final p = img.Image(width: 4000, height: 3000, numChannels: 4);
  final rgba = p.data!.buffer.asUint8List();
  for (var y = 0; y < 3000; y++) {
    for (var x = 0; x < 4000; x++) {
      final i = (y * 4000 + x) * 4;
      rgba[i] = (x * 255 ~/ 4000) ^ ((x ~/ 7 + y ~/ 5) & 3);
      rgba[i + 1] = y * 255 ~/ 3000;
      rgba[i + 2] = ((x + y) ~/ 8) & 255;
      rgba[i + 3] = 255;
    }
  }
  return img.encodePng(p, level: 1);
}

/// A store that keeps no PDF this large.
class _TooLarge extends DemoInvoiceOriginalRepository {
  _TooLarge() : super(storedBy: () => null, now: () => DateTime.utc(2026));
  @override
  Future<InvoiceOriginal> store({
    required String workspaceId,
    required String invoiceId,
    required Uint8List pdf,
    required String xml,
  }) async =>
      throw const InvoiceOriginalRefused(InvoiceOriginalRefusal.tooLarge);
}

/// Runs [run] on the invoice's document flow once its button is tapped.
Future<void> _go(
  WidgetTester tester,
  FakeMoneyRepository money,
  DemoInvoiceOriginalRepository store,
  Future<void> Function(InvoiceDocumentFlow flow, Invoice invoice) run,
) async {
  final workspace = FakeWorkspaceRepository.withWorkspace();
  await money.createInvoice(
    workspaceId: 'ws-1',
    memberId: 'member-1',
    period: '2026-11',
  );
  final invoice = money.invoices.single.copyWith(keepsOriginal: true);
  var done = false;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          money: money,
          workspace: workspace,
          invoiceOriginals: store,
        ),
        testReadyWorkspaceContext(),
        currentWorkspaceProvider.overrideWith(
          (ref) async => workspace.workspaces.single,
        ),
        myPermissionsProvider.overrideWithValue({
          WorkspacePermission.issueInvoices,
        }),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              key: const ValueKey('go'),
              onPressed: () async {
                await readDocumentPolicies(ref);
                if (!context.mounted) return;
                await run(InvoiceDocumentFlow(context, ref), invoice);
                done = true;
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    await tester.tap(find.byKey(const ValueKey('go')));
    await untilReal(() => done, what: 'the invoice document');
  });
}

void main() {
  testWidgets('a header and a footer picture added at 4000 x 3000: the '
      'invoice is kept as its original and is under 1 MB', (tester) async {
    final money = FakeMoneyRepository();
    await tester.runAsync(() async {
      final large = _large();
      for (final name in ['header', 'footer']) {
        final picture = await reportPictureForPrint(large);
        await money.uploadReportImage(
          'ws-1',
          name: name,
          bytes: picture.bytes,
          contentType: picture.contentType,
        );
      }
    });
    money.pdfTemplate = const InvoicePdfTemplate(
      header: '![header|300|center]',
      footer: '![footer|300|center]',
    );
    InvoiceDocument? document;
    await _go(
      tester,
      money,
      DemoInvoiceOriginalRepository(
        storedBy: () => 'user-1',
        now: () => DateTime.utc(2026, 12),
      ),
      (flow, invoice) async => document = await flow.documentOf(invoice),
    );
    expect(document!.source, InvoiceDocumentSource.original);
    expect(document!.bytes.length, lessThan(1000 * 1000));
    expect(
      String.fromCharCodes(document!.bytes),
      contains(RegExp(r'/Subtype\s*/Image')),
      reason: 'the pictures are in the document',
    );
    // ignore: avoid_print
    print('PDF with two pictures: ${document!.bytes.length} bytes');
  });

  testWidgets('an original refused for its weight says so, and its action '
      'opens the picture library', (tester) async {
    await _go(
      tester,
      FakeMoneyRepository(),
      _TooLarge(),
      (flow, invoice) => flow.fileFor(invoice, const []),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.textContaining('brings them to print size'),
      findsOneWidget,
      reason: 'the text says what the action leads to',
    );
    await tester.tap(
      find.byKey(const ValueKey('invoice-original-open-picture-library')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}

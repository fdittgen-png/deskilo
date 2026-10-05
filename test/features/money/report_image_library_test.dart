// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Workspace images remain reusable after upload, refresh cached replacements,
// and embed in both banded and positioned PDFs.
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/core/files/file_picker.dart';
import 'package:deskilo/features/money/domain/invoice_pdf.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/domain/report_layout/layout_render.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:deskilo/features/money/presentation/widgets/report_image_picker.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/fake_money_repository.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
);

class _Images extends FakeMoneyRepository {
  String? workspace;
  String? type;
  int reads = 0;

  @override
  Future<void> uploadReportImage(
    String workspaceId, {
    required String name,
    required List<int> bytes,
    required String contentType,
  }) async {
    workspace = workspaceId;
    type = contentType;
    await super.uploadReportImage(
      workspaceId,
      name: name,
      bytes: bytes,
      contentType: contentType,
    );
  }

  @override
  Future<Uint8List?> fetchReportImage(String workspaceId, String name) {
    reads++;
    return super.fetchReportImage(workspaceId, name);
  }
}

void main() {
  test(
    'a shared library picture embeds in bands and positioned reports',
    () async {
      final images = {'shared-logo': _png};
      final banded = await buildBandedLetterPdf(
        report: const InvoiceReport(
          header: [ReportImage('shared-logo')],
          body: [ReportText('Document')],
          footer: [],
        ),
        pageLabel: 'Page',
        documentTitle: 'Report',
        reportImages: images,
        baseFont: pw.Font.helvetica(),
        boldFont: pw.Font.helveticaBold(),
      );
      final positioned = await buildLayoutPdf(
        document: renderLayoutDocument(
          '<report-layout><header>'
          '<image name="shared-logo"/></header>'
          '<body><text>Document</text></body></report-layout>',
          const {},
        ),
        data: const {},
        documentTitle: 'Report',
        pageLabel: 'Page',
        images: images,
        baseFont: pw.Font.helvetica(),
        boldFont: pw.Font.helveticaBold(),
      );
      for (final bytes in [banded, positioned]) {
        expect(latin1.decode(bytes), matches(RegExp(r'/Subtype\s*/Image')));
      }
    },
  );

  testWidgets(
    'upload replaces cached bytes and remains reusable on reopening',
    (tester) async {
      final repository = _Images()..reportImages['logo-jpg'] = _png;
      late WidgetRef captured;
      String? selected;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...standardTestOverrides(
              money: repository,
              workspace: FakeWorkspaceRepository.withWorkspace(),
            ),
            filePickerProvider.overrideWithValue(
              (group) async =>
                  XFile.fromData(_png, name: 'logo.jpg', path: 'logo.jpg'),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) {
                captured = ref;
                return Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      selected = await showReportImagePicker(context, ref);
                    },
                    child: const Text('Open'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(repository.reads, 1);
      await tester.tap(find.byKey(const ValueKey('report-image-upload')));
      await tester.pumpAndSettle();
      expect(repository.workspace, 'ws-1');
      expect(repository.type, 'image/jpeg');
      expect(
        repository.reads,
        2,
        reason: 'replacement invalidates the byte cache',
      );
      expect(
        await captured.read(reportImageBytesProvider('logo-jpg').future),
        _png,
      );
      await tester.tap(find.byKey(const ValueKey('report-image-logo-jpg')));
      await tester.pumpAndSettle();
      expect(selected, 'logo-jpg');
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('report-image-logo-jpg')),
        findsOneWidget,
      );
    },
  );
}

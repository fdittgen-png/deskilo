// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Batch covers resolve workspace-library images and paginate independently
// of the fixed-size badge grid, with stable bottom-aligned footer content.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/presentation/batch_cover.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/workspace/domain/badge_pdf.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pdf_geometry.dart';

void main() {
  testWidgets('badge covers embed the selected shared workspace image', (
    tester,
  ) async {
    final money = FakeMoneyRepository()
      ..pdfTemplate = InvoicePdfTemplate.empty.withDoc(
        'badges',
        const ReportBands(header: '![shared-logo]', body: 'Cover'),
      );
    money.reportImages['shared-logo'] = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
    );
    late WidgetRef ref;
    late BuildContext context;
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          money: money,
          workspace: FakeWorkspaceRepository.withWorkspace(),
        ),
        child: MaterialApp(
          home: Consumer(
            builder: (c, r, _) {
              r.watch(currentWorkspaceProvider);
              r.watch(enabledFeaturesProvider);
              r.watch(invoicePdfTemplateProvider);
              r.watch(reportImageBytesProvider('shared-logo'));
              ref = r;
              context = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final pending = batchCover(
      context,
      ref,
      docId: 'badges',
      data: const {'workspace': 'Space', 'member': 'Member'},
    );
    await tester.pumpAndSettle();
    final cover = await pending;
    expect(cover, isNotNull);
    await tester.runAsync(() async {
      final bytes = await buildBadgePdf(
        workspaceName: 'Space',
        memberName: 'Member',
        token: 'synthetic-token',
        hint: 'Present badge',
        baseFont: pw.Font.helvetica(),
        boldFont: pw.Font.helveticaBold(),
        coverHeader: cover!.header,
        coverBody: cover.body,
        coverFooter: cover.footer,
        coverContinuation: cover.continuation,
      );
      expect(latin1.decode(bytes), matches(RegExp(r'/Subtype\s*/Image')));
    });
  });

  test('long cover paginates before the unchanged badge grid', () async {
    final bytes = await buildBadgePdf(
      workspaceName: 'Space',
      memberName: 'Member',
      token: 'synthetic-token',
      hint: 'Present badge',
      baseFont: pw.Font.helvetica(),
      boldFont: pw.Font.helveticaBold(),
      coverHeader: [pw.Text('FIRST_ADDRESS')],
      coverContinuation: [pw.Text('CONTINUATION')],
      coverBody: List.generate(110, (i) => pw.Text('Cover row $i')),
      coverFooter: [pw.Text('FIXED_FOOTER')],
    );
    Directory('build/report-cover').createSync(recursive: true);
    File('build/report-cover/badges.pdf').writeAsBytesSync(bytes);
    final streams = pageStreams(bytes);
    expect(streams.length, greaterThanOrEqualTo(3));
    expect(streams.first, contains('FIRST_ADDRESS'));
    expect(streams[1], isNot(contains('FIRST_ADDRESS')));
    expect(streams[1], contains('CONTINUATION'));
    final ink = textPositions(bytes);
    double footerY(int page) => ink
        .where((p) => p.page == page && p.xMm < 150)
        .map((p) => p.yMm)
        .reduce((a, b) => a > b ? a : b);
    expect(footerY(2), closeTo(footerY(1), .2));
  });
}

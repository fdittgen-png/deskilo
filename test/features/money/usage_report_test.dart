// SPDX-License-Identifier: 0BSD
//
// #873 — the consumption report: a registered letter kind with default
// bands that print what was paid ahead, what was consumed and the
// records behind it; reachable from the Usage face.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/domain/report_kind.dart';
import 'package:deskilo/features/money/presentation/report_defaults.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

String _text(ReportBlock block) => switch (block) {
      ReportHeading(:final text) => text,
      ReportSubheading(:final text) => text,
      ReportText(:final text) => text,
      ReportMuted(:final text) => text,
      ReportTableRow(:final cells) => cells.join(' | '),
      _ => '',
    };

void main() {
  test('the kind is registered and its default bands render the sample', () {
    expect(reportKindById('usage'), isNotNull);
    final report = renderReportBands(
      bands: defaultUsageBands(null),
      data: sampleReportData(null),
    );
    expect(report, isNotNull);
    final header = report!.header.map(_text).join('\n');
    final body = report.body.map(_text).join('\n');
    expect(header, contains('Consumption report'));
    expect(body, contains('What was consumed'));
    expect(body, contains('A1'), reason: 'the records loop prints');
    expect(body, isNot(contains('Overage')),
        reason: 'no overage → the guarded line vanishes');
  });

  testWidgets('the Usage face offers the month report and opens it',
      (tester) async {
    final money = FakeMoneyRepository()
      ..seedUsage(reservedMinutes: 240, actualMinutes: 200);
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: standardTestOverrides(money: money),
      child: const DeskiloApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Money'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('money-face-usage')));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('usage-report-button-face'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    // The report triad (#514): quick view / save / share.
    await tester.tap(find.byKey(const ValueKey('member-doc-quick')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-quick-preview')), findsOneWidget);
    // #496 — the fixture workspace resolves the document language to
    // German, like every member letter.
    expect(find.textContaining('Verbrauchsbericht'), findsWidgets);
  });
}

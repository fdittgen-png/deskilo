// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Business analytics dashboard: the figure with how it moved, the
// evolution over the past periods and where it points, how now compares
// with the past, and what it is made of — all from the same rows as the
// table — and the same content as a PDF. A running period is marked
// provisional; a period the data does not know is a gap and says so; with
// too little history there is no projection and the page says why.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/domain/report_layout/layout_render.dart';
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/core/demo/data/floor_plan_repository.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/core/navigation/navigation_style.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/providers/kpi_providers.dart';
import 'package:deskilo/features/workspace/domain/bi_analysis.dart';
import 'package:deskilo/features/workspace/domain/bi_report_content.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/presentation/widgets/bi_dashboard_content.dart';
import 'package:deskilo/features/workspace/domain/bi_report_pdf.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pdf_geometry.dart';

/// March 2026 (the running month at the fixed clock): 30 of 100 seat-hours
/// reserved, 1000 physical. February: 20 of 80. Before February: not
/// recorded.
class _Kpis implements KpiRepository {
  @override
  Future<SeatCapacityKpi> seatCapacity(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
    String? levelId,
  }) async {
    final march = from.month == 3 && from.year == 2026;
    final (num r, num o, num p) = switch ((march, levelId)) {
      (true, null) => (30, 100, 1000),
      (true, 'level-a') => (20, 60, 600),
      (true, _) => (10, 40, 400),
      (false, null) => (20, 80, 900),
      (false, _) => (10, 40, 450),
    };
    final recorded = !from.isBefore(DateTime.utc(2026, 1, 15));
    return seatCapacityFromJson({
      'seats': 5,
      'physical_seat_hours': recorded ? p : 0,
      'offered_seat_hours': recorded ? o : 0,
      'reserved_seat_hours': recorded ? r : 0,
      'reserved_outside_offered_seat_hours': 0,
      'overlapping_seat_hours': 0,
      'rooms_without_seats': 0,
      'offered_room_hours': 0,
      'reserved_room_hours': 0,
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
      'quality': recorded ? <String>[] : ['not_recorded'],
      'reasons': recorded ? <String>[] : ['history_not_recorded_before'],
      'history_since': '2026-02-01T00:00:00Z',
      'computed_at': '2026-03-15T10:00:00Z',
    });
  }
}

class _Saver {
  Uint8List? bytes;
  String? name;
  Future<String?> call({required Uint8List bytes, required String fileName}) async {
    this.bytes = bytes;
    name = fileName;
    return '/Downloads/$fileName';
  }
}

Future<_Saver> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final saver = _Saver();
  final plan = FakeFloorPlanRepository()
    ..levels.addAll(const [
      Level(id: 'level-a', workspaceId: 'ws-1', name: 'Ground', sortOrder: 0),
      Level(id: 'level-b', workspaceId: 'ws-1', name: 'First', sortOrder: 1),
    ]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: {'capacityKpi': true},
          ),
          floorPlan: plan,
          clock: FixedClock(DateTime(2026, 3, 15, 12)),
        ),
        platformIsWebProvider.overrideWithValue(true),
        webShellProvider.overrideWithValue(true),
        kpiRepositoryProvider.overrideWithValue(_Kpis()),
        fileSaverProvider.overrideWithValue(saver.call),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/bi'),
  );
  await tester.pumpAndSettle();
  return saver;
}

Finder _key(String k) => find.byKey(ValueKey(k));

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(_key(key)).data!;

void main() {
  testWidgets('the dashboard says how it moved, in numbers and in words', (
    tester,
  ) async {
    await _pump(tester);
    expect(_key('bi-dashboard'), findsOneWidget);
    expect(_text(tester, 'bi-value'), '30.0%');
    // March is running: its change against February is provisional.
    final chip = _key('bi-delta-previous');
    expect(chip, findsOneWidget);
    expect(
      find.descendant(of: chip, matching: find.textContaining('≈')),
      findsOneWidget,
    );
    expect(find.textContaining('Provisional'), findsOneWidget);
    expect(_text(tester, 'bi-narrative'), startsWith('Higher than previous period'));
    // A year ago the data does not know: no chip for it, said plainly.
    expect(_key('bi-delta-yearAgo'), findsNothing);
  });

  testWidgets('the evolution reads out a period on tap, a gap says so', (
    tester,
  ) async {
    await _pump(tester);
    expect(
      _text(tester, 'bi-evolution-readout'),
      allOf(contains('March 2026'), contains('running')),
    );
    final box = tester.getRect(_key('bi-evolution'));
    // The left edge is the oldest period: before the recorded history.
    await tester.tapAt(Offset(box.left + 54, box.center.dy));
    await tester.pumpAndSettle();
    expect(_text(tester, 'bi-evolution-readout'), contains('no data'));
    // The right edge is the current one again.
    await tester.tapAt(Offset(box.right - 8, box.center.dy));
    await tester.pumpAndSettle();
    expect(_text(tester, 'bi-evolution-readout'), contains('March 2026'));
  });

  testWidgets('with one complete period there is no projection, and why', (
    tester,
  ) async {
    await _pump(tester);
    expect(
      _text(tester, 'bi-projection-basis'),
      allOf(contains('Not enough history'), contains('1 complete')),
    );
    expect(_key('bi-projection-next'), findsNothing);
  });

  testWidgets('now is compared with the past, a bar each', (tester) async {
    await _pump(tester);
    expect(_key('bi-compare'), findsOneWidget);
    expect(_key('bi-compare-current'), findsOneWidget);
    expect(_key('bi-compare-previous'), findsOneWidget);
    expect(_text(tester, 'bi-compare-previous'), '25.0%');
  });

  testWidgets('what it is made of: shares that add up, with their amounts', (
    tester,
  ) async {
    await _pump(tester);
    // 1000 physical seat-hours: 30 reserved, 70 free, 900 outside opening
    // hours.
    expect(_key('bi-donut'), findsWidgets);
    expect(_text(tester, 'bi-share-reserved'), '3.0%');
    expect(_text(tester, 'bi-share-free'), '7.0%');
    expect(_text(tester, 'bi-share-closed'), '90.0%');
    expect(find.text('Outside opening hours'), findsOneWidget);
  });

  testWidgets('the table and the chart are still one tap away', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Table'));
    await tester.pumpAndSettle();
    expect(_key('bi-table'), findsOneWidget);
    expect(_key('bi-dashboard'), findsNothing);
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(_key('bi-dashboard'), findsOneWidget);
  });

  testWidgets('Export as PDF saves the dashboard as a PDF', (tester) async {
    final saver = await _pump(tester);
    await tester.tap(_key('bi-export-pdf'));
    await tester.pumpAndSettle();
    expect(saver.name, endsWith('.pdf'));
    expect(saver.name, contains('analytics-2026-03'));
    final bytes = saver.bytes!;
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(3000));
    expect(find.textContaining('/Downloads/'), findsOneWidget);
  });

  test('the report prints a gap as a gap and the projection as an estimate', () async {
    const end = BiPeriod(BiGrain.month, 2026, 10);
    final values = <num?>[null, null, 100, 120, 110, 140, 150, 160, 170, 180, 190, 200, 120];
    final series = BiSeries([
      for (final (i, v) in values.indexed)
        BiSeriesPoint(
          period: end.shift(i - (values.length - 1)),
          value: v,
          partial: i == values.length - 1,
        ),
    ]);
    final forecast = forecastOf(series, aggregation: KpiAggregation.sum);
    expect(forecast, isNotNull);
    String format(num v) => '${v.round()} €';
    final content = BiDashboardContent(
      title: 'Invoiced',
      period: 'October 2026',
      figure: '120 €',
      basis: 'From 3 invoices',
      series: series,
      forecast: forecast,
      chips: const [],
      bars: [
        for (final bar in comparisonBars(series))
          BiBarContent(bar: bar, change: null, direction: BiDirection.unknown),
      ],
      compositions: const [],
      notes: const ['The period is not over.'],
      projectionBasis: 'A straight line through the last 10 complete periods.',
      projectionNext: 'November 2026: 210 € · Estimate',
      format: format,
      periodLabel: (p) => '${p.index}/${p.year}',
      shortLabel: (p) => '${p.index}',
      kindLabel: (k) => k.name,
      projectedLabel: 'Estimate',
      noDataLabel: 'no data',
      partialLabel: 'running',
      noComparisonLabel: 'No comparison yet',
      evolutionTitle: 'Evolution',
      compareTitle: 'Compared with the past',
    );
    final logo = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==');
    final bytes = await buildBiReportPdf(
      report: const InvoiceReport(header: [ReportHeading('Custom analytics'), ReportImage('logo')],
        body: [ReportText('Owner introduction')], footer: [ReportText('Workspace footer')]),
      images: {'logo': logo},
      title: 'Business analytics',
      workspaceName: 'Workspace',
      subtitle: 'October 2026',
      producedOn: 'Produced today',
      estimateNote: 'Dashed lines are estimates.',
      sections: [content, content],
      baseFont: pw.Font.ttf(
        ByteData.sublistView(File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync()),
      ),
      boldFont: pw.Font.ttf(
        ByteData.sublistView(File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync()),
      ),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(4000));
    expect(RegExp(r'/Subtype\s*/Image').hasMatch(latin1.decode(bytes)), isTrue);
    final positioned = await buildLayoutPdf(
      document: renderLayoutDocument('<report-layout><header><text>Custom analytics</text></header>'
        '<body><text>Owner introduction</text></body><footer><text>Workspace footer</text></footer></report-layout>', const {}),
      data: const {}, documentTitle: 'Business analytics', pageLabel: 'Page',
      baseFont: pw.Font.ttf(ByteData.sublistView(File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync())),
      boldFont: pw.Font.ttf(ByteData.sublistView(File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync())),
      additionalBody: biReportBodyWidgets([content, content], 'Dashed lines are estimates.'),
    );
    final out = Directory('build/report-bi')..createSync(recursive: true);
    for (final entry in {'banded': bytes, 'positioned': positioned}.entries) {
      File('${out.path}/${entry.key}.pdf').writeAsBytesSync(entry.value);
      final ink = textPositions(entry.value);
      expect(ink.length, greaterThan(100), reason: 'Both native analyses survive the custom design');
      expect(ink.map((i) => i.page).toSet().length, greaterThan(1));
    }
  });
}

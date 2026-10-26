// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2581 — an export is planned into the figures of the report, each asked
// once, and the server's answer becomes one frozen snapshot: a ratio keeps
// its numerator and denominator (20 / 120, never a rounded label), each
// amount its own currency, a figure the server could not give is a failure
// and never a zero, a card the export cannot answer is left out and said,
// and an answer about another workspace, format or without a digest is
// refused. A later answer is another snapshot; the first keeps its values.
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/bi_report_definition.dart';
import 'package:deskilo/features/workspace/domain/bi_report_snapshot.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/bi_report_fixture.dart';

void main() {
  group('the plan', () {
    test('asks every figure once, in the report\'s order', () {
      final plan = fixturePlan();
      // Capacity: September (card) shares the line's last month; the line
      // asks July to September. Invoiced: September. Collected: three months.
      expect(plan.requests.map((r) => r.metricId).toList(), [
        'capacity.seat_utilisation',
        'capacity.seat_utilisation',
        'capacity.seat_utilisation',
        'finance.invoiced',
        'finance.collected',
        'finance.collected',
        'finance.collected',
        'purchases.ap_outstanding',
      ]);
      expect(plan.items.map((i) => i.visual.id), [
        'v1',
        'v2',
        'v4',
        'v5',
        'v6',
      ], reason: 'the text v3 asks nothing');
      expect(plan.items.first.keys.single, plan.items[1].keys.last);
      expect(plan.items[1].periods.map((p) => p.wire), [
        '2026-07',
        '2026-08',
        '2026-09',
      ]);
    });

    test('leaves out what it cannot answer, and says why', () {
      expect(
        {for (final l in fixturePlan().leftOut) l.visual.id: l.reason},
        {'v7': BiLeftOutReason.unsupportedScope},
        reason: 'the plan cannot narrow v7; whether v6 exports is the '
            'server\'s to say',
      );
      final s = fixtureSnapshot();
      expect(
        [for (final l in s.plan.leftOut) (l.visual.id, l.reason)],
        [
          ('v6', BiLeftOutReason.notExportable),
          ('v7', BiLeftOutReason.unsupportedScope),
        ],
        reason: 'the server\'s 0A000 leaves v6 out, in the report\'s order',
      );
      expect(s.visuals.map((v) => v.item.visual.id), ['v1', 'v2', 'v4', 'v5']);
      expect(s.partial, isTrue);
    });

    test('a metric this client does not know is left out unasked', () {
      const report = BiReportDefinition(
        period: BiReportPeriod.fixed(BiGrain.month, '2026-09'),
        pages: [
          BiReportPage(
            id: 'p1',
            title: 'Mixed',
            visuals: [
              BiReportVisual(
                id: 'v1',
                type: BiVisualType.kpi,
                metricId: 'finance.invoiced',
                layout: BiVisualLayout(order: 0),
              ),
              BiReportVisual(
                id: 'v2',
                type: BiVisualType.kpi,
                metricId: 'nobody.knows',
                layout: BiVisualLayout(order: 1),
              ),
            ],
          ),
        ],
      );
      final plan = fixturePlan(report: report);
      expect(plan.requests.map((r) => r.metricId), ['finance.invoiced']);
      expect(plan.leftOut.single.reason, BiLeftOutReason.notExportable);
    });

    test('nothing the server answers in an export is nothing to export', () {
      const report = BiReportDefinition(
        period: BiReportPeriod.fixed(BiGrain.month, '2026-09'),
        pages: [
          BiReportPage(
            id: 'p1',
            title: 'Purchases',
            visuals: [
              BiReportVisual(
                id: 'v1',
                type: BiVisualType.kpi,
                metricId: 'purchases.ap_outstanding',
                layout: BiVisualLayout(order: 0),
              ),
            ],
          ),
        ],
      );
      final plan = fixturePlan(report: report);
      expect(
        () => biReportSnapshotOf(
          plan,
          fixtureAnswer(plan),
          source: fixtureSource,
          format: BiExportFormat.pdf,
        ),
        throwsA(
          isA<BiExportRefused>().having(
            (e) => e.failure,
            'failure',
            BiExportFailure.empty,
          ),
        ),
      );
    });

    test('narrows the capacity figure to one level, never widens it', () {
      const report = BiReportDefinition(
        period: BiReportPeriod.fixed(BiGrain.month, '2026-09'),
        filters: [BiReportFilter('level', 'eq', 'l1')],
        pages: [
          BiReportPage(
            id: 'p1',
            title: 'Level',
            visuals: [
              BiReportVisual(
                id: 'v1',
                type: BiVisualType.kpi,
                metricId: 'capacity.seat_utilisation',
                layout: BiVisualLayout(order: 0),
              ),
              BiReportVisual(
                id: 'v2',
                type: BiVisualType.kpi,
                metricId: 'finance.invoiced',
                layout: BiVisualLayout(order: 1),
              ),
            ],
          ),
        ],
      );
      final plan = fixturePlan(report: report);
      expect(plan.requests.single.levelId, 'l1');
      expect(
        plan.leftOut.single.reason,
        BiLeftOutReason.unsupportedScope,
        reason: 'a level filter is not a figure of the whole space\'s money',
      );
    });

    test('refuses a report over the limit and one with nothing to export', () {
      expect(
        () => fixturePlan(limit: 7),
        throwsA(
          isA<BiExportRefused>().having(
            (e) => e.failure,
            'failure',
            BiExportFailure.tooLarge,
          ),
        ),
      );
      expect(fixturePlan(limit: 8).requests, hasLength(8));
      const textOnly = BiReportDefinition(
        period: BiReportPeriod.fixed(BiGrain.month, '2026-09'),
        pages: [
          BiReportPage(
            id: 'p1',
            title: 'Notes',
            visuals: [
              BiReportVisual(
                id: 'v1',
                type: BiVisualType.text,
                text: 'Hi',
                layout: BiVisualLayout(order: 0),
              ),
            ],
          ),
        ],
      );
      expect(
        () => fixturePlan(report: textOnly),
        throwsA(
          isA<BiExportRefused>().having(
            (e) => e.failure,
            'failure',
            BiExportFailure.empty,
          ),
        ),
      );
    });
  });

  group('the snapshot', () {
    test('a ratio is its numerator over its denominator, exactly', () {
      final s = fixtureSnapshot();
      final card = s.visuals.first.figures.single;
      expect(card.measure.numerator, 20);
      expect(card.measure.denominator, 120);
      expect(card.value, 20 / 120);
      expect(card.metric.aggregation, KpiAggregation.ratioOfSums);
    });

    test('each amount keeps its currency; nothing is converted or summed', () {
      final s = fixtureSnapshot();
      final collected = s.visuals.last.figures;
      expect(collected.map((f) => f.currency), ['', 'CHF', 'EUR']);
      expect(collected[1].value, 2500);
      expect(collected[2].value, -1000);
      expect(s.currencies, {'EUR', 'CHF'});
    });

    test('an unanswered figure is a failure, never a zero, and the copy is partial', () {
      final s = fixtureSnapshot();
      final july = s.visuals.last.figures.first;
      expect(july.failure, '22023');
      expect(july.value, isNull);
      expect(s.partial, isTrue);
      expect(s.financial, isTrue);
      expect(
        s.visuals[1].figures[1].qualified,
        isTrue,
        reason: 'August is partial',
      );
    });

    test(
      'an answer the plan did not ask is ignored; one it misses is a failure',
      () {
        final plan = fixturePlan();
        final answer = fixtureAnswer(plan);
        final results = [...answer['results']! as List];
        final dropped = results.removeAt(3) as Map; // invoiced September
        results.add({...dropped, 'request_key': 'forged'});
        final s = biReportSnapshotOf(
          plan,
          {...answer, 'results': results},
          source: fixtureSource,
          format: BiExportFormat.pdf,
        );
        final invoiced = s.visuals[2].figures.single;
        expect(invoiced.value, isNull);
        expect(invoiced.failure, isNotNull);
        expect(s.figures, hasLength(1 + 3 + 1 + 3));
      },
    );

    test('an answer about another workspace, format or without a digest is refused', () {
      final plan = fixturePlan();
      for (final answer in [
        fixtureAnswer(plan, workspaceId: 'ws-2'),
        fixtureAnswer(plan, format: BiExportFormat.csv),
        fixtureAnswer(plan, hash: ''),
        {...fixtureAnswer(plan), 'computed_at': 'yesterday'},
      ]) {
        expect(
          () => biReportSnapshotOf(
            plan,
            answer,
            source: fixtureSource,
            format: BiExportFormat.pdf,
          ),
          throwsA(
            isA<BiExportRefused>().having(
              (e) => e.failure,
              'failure',
              BiExportFailure.invalid,
            ),
          ),
        );
      }
    });

    test('a later answer is another snapshot; the first keeps its values', () {
      final first = fixtureSnapshot();
      final later = fixtureSnapshot(shift: 10);
      expect(first.visuals.first.figures.single.value, 20 / 120);
      expect(later.visuals.first.figures.single.value, 30 / 120);
      expect(first.computedAt, DateTime.utc(2026, 10, 2, 8, 30));
    });
  });
}

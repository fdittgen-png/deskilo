// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2579 C1 — the v2 report definition: a bounded declarative document that
// round-trips exactly, reads a v1 question as one virtual page, keeps ids and
// reading order stable when cards move, and refuses everything it does not
// declare (SQL, formulas, links, widened shapes) instead of guessing.
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/bi_report_definition.dart';
import 'package:deskilo/features/workspace/domain/bi_report_edit.dart';
import 'package:deskilo/features/workspace/domain/bi_saved_view.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _visual(
  String id,
  int order, [
  Map<String, Object?>? over,
]) => {
  'id': id,
  'type': 'kpi',
  'metricId': 'capacity.seat_utilisation',
  'metricVersion': 1,
  'dimension': null,
  'filters': <Object?>[],
  'sort': null,
  'format': null,
  'layout': {'order': order, 'span': 6, 'height': 2},
  'interaction': 'filter',
  'drill': null,
  ...?over,
};

Map<String, Object?> _report({
  List<Map<String, Object?>>? visuals,
  Map<String, Object?>? over,
}) => {
  'v': 2,
  'reportFilters': <Object?>[],
  'period': {'mode': 'relative', 'grain': 'month', 'offset': -1},
  'pages': [
    {
      'id': 'p1',
      'title': 'Page 1',
      'filters': <Object?>[],
      'visuals': visuals ?? [_visual('v1', 0), _visual('v2', 1)],
    },
  ],
  'printStyle': {'paper': 'A4', 'orientation': 'portrait', 'showSources': true},
  ...?over,
};

void main() {
  test('a report round-trips exactly through its JSON', () {
    final json = _report();
    final report = BiReportDefinition.fromJson(json)!;
    expect(report.toJson(), json);
    expect(report.firstPageCards, [
      'capacity.seat_utilisation',
      'capacity.seat_utilisation',
    ]);
  });

  test('a v1 question is one virtual page of KPI cards, in order', () {
    final query = BiQueryContext.tryParse({'grain': 'quarter', 'at': '-1'})!;
    final report = BiReportDefinition.standard(
      query: query,
      cards: ['finance.invoiced', 'capacity.seat_utilisation'],
      pageTitle: 'Page 1',
    );
    expect(report.pages, hasLength(1));
    expect(report.firstPageCards, [
      'finance.invoiced',
      'capacity.seat_utilisation',
    ]);
    expect(report.period.toQuery(), {'grain': 'quarter', 'at': '-1'});
    expect(
      BiReportDefinition.fromJson(report.toJson())!.toJson(),
      report.toJson(),
    );
  });

  test('a fixed period keeps its period', () {
    final json = _report(
      over: {
        'period': {'mode': 'fixed', 'grain': 'month', 'at': '2026-02'},
      },
    );
    expect(BiReportDefinition.fromJson(json)!.period.toQuery(), {
      'at': '2026-02',
    });
    for (final bad in ['2026-13', '2026-Q1', 'last month']) {
      expect(
        BiReportDefinition.fromJson(
          _report(
            over: {
              'period': {'mode': 'fixed', 'grain': 'month', 'at': bad},
            },
          ),
        ),
        isNull,
        reason: bad,
      );
    }
  });

  test('a definition opens through BiViewDefinition, v1 stays v1', () {
    final v2 = BiViewDefinition.fromJson(_report())!;
    expect(v2.report, isNotNull);
    expect(v2.cards, hasLength(2));
    expect(v2.toJson()['v'], 2);
    final v1 = BiViewDefinition.fromJson({
      'v': 1,
      'query': {'by': 'level'},
      'cards': ['capacity.seat_utilisation'],
    })!;
    expect(v1.report, isNull);
    expect(v1.toJson()['v'], 1);
  });

  test('moving a card keeps ids and renumbers the reading order', () {
    final visuals = BiReportDefinition.fromJson(_report())!.pages.first.visuals;
    final moved = biMoveVisual(visuals, 0, 1);
    expect(moved.map((v) => v.id), ['v2', 'v1']);
    expect(moved.map((v) => v.layout.order), [0, 1]);
    expect(biMoveVisual(visuals, 0, -1).map((v) => v.id), ['v1', 'v2']);
    expect(biNextVisualId(['v1', 'v3']), 'v2');
  });

  group('refuses what it does not declare', () {
    final cases = <String, Map<String, Object?>>{
      'a formula key': _report(
        visuals: [
          _visual('v1', 0, {'formula': 'a+b'}),
        ],
      ),
      'a link as a drill': _report(
        visuals: [
          _visual('v1', 0, {'drill': 'https://evil.example'}),
        ],
      ),
      'an unknown type': _report(
        visuals: [
          _visual('v1', 0, {'type': 'pie3d'}),
        ],
      ),
      'a duplicate id': _report(visuals: [_visual('v1', 0), _visual('v1', 1)]),
      'a duplicate position': _report(
        visuals: [_visual('v1', 0), _visual('v2', 0)],
      ),
      'a span off the grid': _report(
        visuals: [
          _visual('v1', 0, {
            'layout': {'order': 0, 'span': 13, 'height': 2},
          }),
        ],
      ),
      'a text with a metric': _report(
        visuals: [
          _visual('v1', 0, {'type': 'text', 'text': 'hello'}),
        ],
      ),
      'a metric visual without a metric': _report(
        visuals: [
          _visual('v1', 0, {'metricId': null}),
        ],
      ),
      'another version': _report(over: {'v': 3}),
      'an extra top-level key': _report(over: {'token': 'x'}),
      'no page': _report(over: {'pages': <Object?>[]}),
      'a filter with an unknown operator': _report(
        over: {
          'reportFilters': [
            {'dimension': 'level', 'operator': 'like', 'value': 'a'},
          ],
        },
      ),
    };
    for (final e in cases.entries) {
      test(e.key, () => expect(BiReportDefinition.fromJson(e.value), isNull));
    }

    test('five pages, twenty-five visuals and an oversize text', () {
      Map<String, Object?> page(int i) => {
        'id': 'p$i',
        'title': 'P$i',
        'filters': <Object?>[],
        'visuals': <Object?>[],
      };
      expect(
        BiReportDefinition.fromJson(
          _report(
            over: {
              'pages': [for (var i = 1; i <= 5; i++) page(i)],
            },
          ),
        ),
        isNull,
      );
      expect(
        BiReportDefinition.fromJson(
          _report(visuals: [for (var i = 0; i < 25; i++) _visual('v$i', i)]),
        ),
        isNull,
      );
      expect(
        BiReportDefinition.fromJson(
          _report(
            visuals: [
              _visual('v1', 0, {
                'type': 'text',
                'metricId': null,
                'text': 'x' * 501,
              }),
            ],
          ),
        ),
        isNull,
      );
    });

    test('a plain text is kept as it is, never interpreted', () {
      final report = BiReportDefinition.fromJson(
        _report(
          visuals: [
            _visual('v1', 0, {
              'type': 'text',
              'metricId': null,
              'text': '<b>Note</b> & more',
            }),
          ],
        ),
      )!;
      expect(report.pages.first.visuals.first.text, '<b>Note</b> & more');
    });
  });

  test('an older client cannot overwrite a report', () async {
    final repo = InMemoryBiViewRepository();
    final report = BiViewDefinition.fromJson(_report())!;
    final saved = await repo.save(
      'ws',
      scope: BiViewScope.private,
      name: 'R',
      definition: report,
      expectedRevision: 0,
    );
    await expectLater(
      repo.save(
        'ws',
        id: saved.id,
        scope: BiViewScope.private,
        name: 'R',
        definition: const BiViewDefinition(query: {'grain': 'year'}),
        expectedRevision: saved.revision,
      ),
      throwsA(
        isA<BiViewRefused>().having(
          (e) => e.failure,
          'failure',
          BiViewFailure.unsupported,
        ),
      ),
    );
    expect((await repo.list('ws')).single.definition!.report, isNotNull);
  });

  test('with the designer off no report is written', () async {
    final repo = InMemoryBiViewRepository(reportsEnabled: false);
    await expectLater(
      repo.save(
        'ws',
        scope: BiViewScope.private,
        name: 'R',
        definition: BiViewDefinition.fromJson(_report())!,
        expectedRevision: 0,
      ),
      throwsA(isA<BiViewRefused>()),
    );
    // v1 views are untouched by the flag.
    final v1 = await repo.save(
      'ws',
      scope: BiViewScope.private,
      name: 'Q',
      definition: const BiViewDefinition(),
      expectedRevision: 0,
    );
    expect(v1.revision, 1);
  });
}

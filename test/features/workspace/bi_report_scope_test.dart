// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2579 C2 — a saved report is written safely and read within the reader's
// rights. Scopes intersect (report ∩ page ∩ visual ∩ selection) and a lower
// level that would widen a higher one is refused, never read as an override;
// a filter names a registered dimension, the same list as the server's; a
// relative period moves with the workspace clock, a fixed one never does; a
// report stays within the space's limits. The store answers like the server:
// one revision per request however often it is retried, a reused request id
// with another write refused, two editors on one revision — one wins, the
// other is told; a reader is handed only the figures they may read (the ids
// of the others never arrive) and cannot save over what they were not shown;
// a figure at another version is unsupported, an unknown one invalid.
import 'dart:io';

import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/bi_report_definition.dart';
import 'package:deskilo/features/workspace/domain/bi_report_limits.dart';
import 'package:deskilo/features/workspace/domain/bi_saved_view.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:flutter_test/flutter_test.dart';

const _capacity = 'capacity.seat_utilisation';
const _invoiced = 'finance.invoiced';

BiReportFilter _f(String op, String value) =>
    BiReportFilter('level', op, value);

Map<String, Object?> _visual(
  String id,
  int order, {
  String metric = _capacity,
  List<Map<String, Object?>> filters = const [],
}) => {
  'id': id,
  'type': 'kpi',
  'metricId': metric,
  'metricVersion': 1,
  'dimension': null,
  'filters': filters,
  'sort': null,
  'format': null,
  'layout': {'order': order, 'span': 6, 'height': 2},
  'interaction': 'filter',
  'drill': null,
};

Map<String, Object?> _filter(String op, String value, [String dim = 'level']) =>
    {'dimension': dim, 'operator': op, 'value': value};

Map<String, Object?> _report({
  List<Map<String, Object?>> reportFilters = const [],
  List<Map<String, Object?>> pageFilters = const [],
  List<Map<String, Object?>> visualFilters = const [],
  List<Map<String, Object?>>? pages,
}) => {
  'v': 2,
  'reportFilters': reportFilters,
  'period': {'mode': 'relative', 'grain': 'month', 'offset': -1},
  'pages':
      pages ??
      [
        {
          'id': 'p1',
          'title': 'Capacity',
          'filters': pageFilters,
          'visuals': [_visual('v1', 0, filters: visualFilters)],
        },
      ],
  'printStyle': {'paper': 'A4', 'orientation': 'portrait', 'showSources': true},
};

/// Capacity on its page, finance on the second, as two editors would save it.
Map<String, Object?> _twoPages() => _report(
  pages: [
    {
      'id': 'p1',
      'title': 'Capacity',
      'filters': <Object?>[],
      'visuals': [_visual('v1', 0)],
    },
    {
      'id': 'p2',
      'title': 'Money',
      'filters': <Object?>[],
      'visuals': [_visual('v2', 0, metric: _invoiced), _visual('v3', 1)],
    },
  ],
);

BiViewDefinition _def(Map<String, Object?> json) =>
    BiViewDefinition.fromJson(json)!;

Matcher _refused(BiViewFailure f) =>
    throwsA(isA<BiViewRefused>().having((e) => e.failure, 'failure', f));

SettingDefinition _setting(String key, int max) => SettingDefinition(
  key: key,
  type: SettingType.integer,
  defaultValue: max,
  min: 1,
  max: max,
  unit: 'pages',
  group: 'kpi',
  scopes: {SettingScope.workspace},
);

void main() {
  group('scopes intersect, never widen', () {
    test('report ∩ page ∩ visual ∩ selection', () {
      final report = BiReportDefinition.fromJson(
        _report(
          reportFilters: [_filter('in', 'l1,l2')],
          pageFilters: [_filter('eq', 'l1')],
          visualFilters: [_filter('neq', 'l3')],
        ),
      )!;
      final page = report.pages.single;
      final scope = report.scopeOf(page, page.visuals.single)!;
      expect(scope.map((f) => '${f.operator}:${f.value}'), [
        'in:l1,l2',
        'eq:l1',
        'neq:l3',
      ]);
      // A selection inside the page's level narrows it further…
      expect(
        report.scopeOf(page, page.visuals.single, selection: [_f('eq', 'l1')]),
        hasLength(4),
      );
      // …one outside it would widen it, and is refused.
      expect(
        report.scopeOf(page, page.visuals.single, selection: [_f('eq', 'l2')]),
        isNull,
      );
    });

    test('a page or visual filter that would widen is refused on read', () {
      expect(
        BiReportDefinition.fromJson(
          _report(
            reportFilters: [_filter('eq', 'l1')],
            pageFilters: [_filter('eq', 'l2')],
          ),
        ),
        isNull,
      );
      expect(
        BiReportDefinition.fromJson(
          _report(
            pageFilters: [_filter('in', 'l1,l2')],
            visualFilters: [_filter('in', 'l1,l3')],
          ),
        ),
        isNull,
      );
      expect(
        BiReportDefinition.fromJson(
          _report(
            reportFilters: [_filter('neq', 'l1')],
            visualFilters: [_filter('eq', 'l1')],
          ),
        ),
        isNull,
      );
      // Positive control: the same shapes narrowing are kept.
      expect(
        BiReportDefinition.fromJson(
          _report(
            reportFilters: [_filter('in', 'l1,l2')],
            pageFilters: [_filter('eq', 'l2')],
            visualFilters: [_filter('neq', 'l1')],
          ),
        ),
        isNotNull,
      );
    });

    test('a filter or grouping names a registered dimension', () {
      expect(
        BiReportDefinition.fromJson(
          _report(reportFilters: [_filter('eq', 'x', 'member_email')]),
        ),
        isNull,
      );
      final grouped = _report();
      ((grouped['pages']! as List).single as Map)['visuals'] = [
        {..._visual('v1', 0), 'dimension': 'person'},
      ];
      expect(BiReportDefinition.fromJson(grouped), isNull);
      expect(
        BiReportDefinition.fromJson(
          _report(reportFilters: [_filter('eq', 'x')]),
        ),
        isNotNull,
      );
    });

    test('the server lists the same dimensions as the catalogue', () {
      final sql =
          Directory('supabase/migrations')
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.sql'))
              .map((f) => (f.path, f.readAsStringSync()))
              .where(
                (e) => e.$2.contains('function public.bi_report_dimensions()'),
              )
              .toList()
            ..sort((a, b) => a.$1.compareTo(b.$1));
      final body = RegExp(
        r"function public\.bi_report_dimensions\(\)[\s\S]*?array\[([^\]]*)\]",
      ).firstMatch(sql.last.$2)!.group(1)!;
      final listed = RegExp(r"'([a-z_.]+)'").allMatches(body).map((m) => m[1]);
      expect(listed.toSet(), {for (final k in kpiCatalogue) ...k.dimensions});
    });
  });

  test(
    'a relative period moves with the workspace clock; a fixed one stays',
    () {
      const relative = BiReportPeriod.relative(BiGrain.month, -1);
      expect(relative.resolve(DateTime(2026, 3, 15))!.wire, '2026-02');
      expect(relative.resolve(DateTime(2026))!.wire, '2025-12');
      const fixed = BiReportPeriod.fixed(BiGrain.quarter, '2025-Q4');
      expect(fixed.resolve(DateTime(2026, 3, 15))!.wire, '2025-Q4');
      expect(fixed.resolve(DateTime(2027, 9))!.wire, '2025-Q4');
    },
  );

  test('two pages, capacity and finance, keep their ids, order and pages', () {
    final report = BiReportDefinition.fromJson(_twoPages())!;
    expect(report.toJson(), _twoPages());
    expect(BiReportDefinition.cardsOf(report.pages[1]), [_invoiced, _capacity]);
    expect(report.queryOfPage(1)!.cards, [_invoiced, _capacity]);
    // No figure is ever part of a definition.
    expect(report.toJson().toString(), isNot(contains('minor')));
  });

  group('the space\'s report limits', () {
    test('defaults are the platform guards; a space may lower them', () {
      const limits = BiReportLimits();
      expect(limits.maxPages, BiReportDefinition.maxPages);
      expect(limits.maxVisuals, BiReportDefinition.maxVisuals);
      expect(limits.maxBytes, BiReportDefinition.maxBytes);
      final two = BiReportDefinition.fromJson(_twoPages())!;
      expect(limits.admits(two), isTrue);
      final settings = SettingsSet(
        {
          BiReportLimits.pagesKey: _setting(BiReportLimits.pagesKey, 4),
          BiReportLimits.visualsKey: _setting(BiReportLimits.visualsKey, 24),
        },
        {BiReportLimits.pagesKey: 1, BiReportLimits.visualsKey: 3},
      );
      final small = BiReportLimits.fromSettings(settings);
      expect(small.maxPages, 1);
      expect(small.maxVisuals, 3);
      // A registry that predates the bytes key keeps its default.
      expect(small.maxBytes, BiReportDefinition.maxBytes);
      expect(small.admits(two), isFalse);
      expect(small.canAddPage(two), isFalse);
      expect(small.canAddVisual(two), isFalse);
      expect(BiReportLimits.fromSettings(null).maxPages, 4);
    });

    test('the store refuses a report over the space\'s limits', () async {
      final repo = InMemoryBiViewRepository(
        limits: const BiReportLimits(maxPages: 1),
      );
      await expectLater(
        repo.save(
          'ws',
          scope: BiViewScope.private,
          name: 'Two',
          definition: _def(_twoPages()),
          expectedRevision: 0,
        ),
        _refused(BiViewFailure.invalid),
      );
      expect(await repo.list('ws'), isEmpty);
    });
  });

  group('the store answers like the server', () {
    test('a retried request is one revision; another write under its id is '
        'refused', () async {
      final repo = InMemoryBiViewRepository();
      final def = _def(_twoPages());
      Future<BiSavedView> save(BiViewDefinition d, {int rev = 0, String? id}) =>
          repo.save(
            'ws',
            id: id,
            scope: BiViewScope.private,
            name: 'R',
            definition: d,
            expectedRevision: rev,
            requestId: 'req-1',
          );
      final first = await save(def);
      final again = await save(def);
      expect(again.id, first.id);
      expect(again.revision, 1);
      expect(await repo.list('ws'), hasLength(1));
      await expectLater(save(_def(_report())), _refused(BiViewFailure.invalid));
      expect(
        (await repo.list('ws')).single.definition!.report!.pages,
        hasLength(2),
      );
    });

    test('two editors on one revision: one saves, the other is told', () async {
      final repo = InMemoryBiViewRepository();
      final base = await repo.save(
        'ws',
        scope: BiViewScope.workspace,
        name: 'Team',
        definition: _def(_twoPages()),
        expectedRevision: 0,
      );
      Future<BiSavedView> edit(String requestId) => repo.save(
        'ws',
        id: base.id,
        scope: BiViewScope.workspace,
        name: 'Team $requestId',
        definition: base.definition!,
        expectedRevision: base.revision,
        requestId: requestId,
      );
      expect((await edit('a')).revision, 2);
      await expectLater(edit('b'), _refused(BiViewFailure.stale));
      expect((await repo.list('ws')).single.name, 'Team a');
    });

    test('an operational reader of a mixed team report receives only what '
        'they may read, and cannot save over the rest', () async {
      final repo = InMemoryBiViewRepository();
      final shared = await repo.save(
        'ws',
        scope: BiViewScope.workspace,
        name: 'Mixed',
        definition: _def(_twoPages()),
        expectedRevision: 0,
      );
      repo.readable = {_capacity};
      final read = (await repo.list('ws')).single;
      expect(read.withheld, 1);
      final pages = read.definition!.report!.pages;
      expect(pages.map((p) => p.id), ['p1', 'p2']);
      expect(BiReportDefinition.cardsOf(pages[1]), [_capacity]);
      expect(
        read.definition!.report!.toJson().toString(),
        isNot(contains(_invoiced)),
      );
      await expectLater(
        repo.save(
          'ws',
          id: shared.id,
          scope: BiViewScope.workspace,
          name: 'Mixed',
          definition: read.definition!,
          expectedRevision: read.revision,
        ),
        _refused(BiViewFailure.forbidden),
      );
      // A figure the writer may not read is never saved either…
      await expectLater(
        repo.save(
          'ws',
          scope: BiViewScope.private,
          name: 'Mine',
          definition: _def(_twoPages()),
          expectedRevision: 0,
        ),
        _refused(BiViewFailure.forbidden),
      );
      // …while a copy of what they were shown is theirs to keep.
      final copy = await repo.save(
        'ws',
        scope: BiViewScope.private,
        name: 'Mine',
        definition: read.definition!,
        expectedRevision: 0,
      );
      expect(copy.withheld, 0);
      // Rights given back: the team report is whole again.
      repo.readable = null;
      expect(
        BiReportDefinition.cardsOf(
          (await repo.list('ws'))
              .firstWhere((v) => v.id == shared.id)
              .definition!
              .report!
              .pages[1],
        ),
        [_invoiced, _capacity],
      );
    });

    test('a question left with none of its figures is refused, not "all"', () {
      final check = checkView(const BiViewDefinition(), {
        _capacity,
      }, withheld: 1);
      expect(check.query, isNull);
      expect(checkView(const BiViewDefinition(), {_capacity}).query, isNotNull);
      final emptyPage = BiViewDefinition.ofReport(
        BiReportDefinition.fromJson(_report())!
            .withFirstPage(const BiReportPage(id: 'p1', title: 'Empty')),
      );
      expect(checkView(emptyPage, {_capacity}).query, isNull);
    });

    test('another version is unsupported, an unknown metric invalid', () async {
      final repo = InMemoryBiViewRepository();
      final old = _report(
        pages: [
          {
            'id': 'p1',
            'title': 'Old',
            'filters': <Object?>[],
            'visuals': [
              {..._visual('v1', 0), 'metricVersion': 7},
            ],
          },
        ],
      );
      await expectLater(
        repo.save(
          'ws',
          scope: BiViewScope.private,
          name: 'Old',
          definition: _def(old),
          expectedRevision: 0,
        ),
        _refused(BiViewFailure.unsupported),
      );
      await expectLater(
        repo.save(
          'ws',
          scope: BiViewScope.private,
          name: 'Unknown',
          definition: const BiViewDefinition(cards: ['capacity.made_up']),
          expectedRevision: 0,
        ),
        _refused(BiViewFailure.invalid),
      );
    });

    test('team views are written only by someone who may share them', () async {
      final repo = InMemoryBiViewRepository(canManage: false);
      await expectLater(
        repo.save(
          'ws',
          scope: BiViewScope.workspace,
          name: 'Team',
          definition: const BiViewDefinition(cards: [_capacity]),
          expectedRevision: 0,
        ),
        _refused(BiViewFailure.forbidden),
      );
      final mine = await repo.save(
        'ws',
        scope: BiViewScope.private,
        name: 'Mine',
        definition: const BiViewDefinition(cards: [_capacity]),
        expectedRevision: 0,
      );
      expect(mine.scope, BiViewScope.private);
    });
  });

  test('a stored view says how much was withheld; a bad count is refused', () {
    final view = BiSavedView.fromJson({
      'id': 'x',
      'scope': 'workspace',
      'name': 'Mixed',
      'definition': {
        'v': 1,
        'cards': [_capacity],
      },
      'revision': 3,
      'withheld': 2,
    })!;
    expect(view.withheld, 2);
    expect(view.atRevision(5).revision, 5);
    expect(view.atRevision(5).withheld, 2);
    expect(
      BiSavedView.fromJson({
        'id': 'x',
        'scope': 'private',
        'name': 'n',
        'revision': 1,
        'withheld': -1,
      }),
      isNull,
    );
  });
}

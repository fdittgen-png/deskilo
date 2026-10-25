// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The saved views in memory, under the server's rules (`bi_view_save`,
// `bi_view_json`): the demonstration and the tests use it, so it refuses
// what the server refuses — a stale revision, a team view without the right
// to share, a figure the writer may not read, a report over the space's
// limits, an older writer over a report — answers a retried request once,
// and hands every reader only the figures they may read.
//
// Pure Dart.
library;

import 'dart:convert';

import 'bi_report_definition.dart';
import 'bi_report_limits.dart';
import 'bi_saved_view.dart';
import 'kpi_contract.dart';

/// The metric ids [definition] names: a question's cards and versions, or
/// every visual of every page of a report.
Set<String> _metricsOf(BiViewDefinition definition) {
  final report = definition.report;
  if (report == null) {
    return {...definition.cards, ...definition.metricVersions.keys};
  }
  return {
    for (final p in report.pages)
      for (final v in p.visuals) ?v.metricId,
  };
}

/// [definition] as a reader for whom only [readable] metrics exist: the
/// others are taken out (with their saved versions), never renamed.
BiViewDefinition _definitionFor(
  BiViewDefinition definition,
  bool Function(String metric) readable,
) {
  final report = definition.report;
  if (report == null) {
    return BiViewDefinition(
      query: definition.query,
      cards: [...definition.cards.where(readable)],
      metricVersions: {
        for (final MapEntry(:key, :value) in definition.metricVersions.entries)
          if (readable(key)) key: value,
      },
    );
  }
  return BiViewDefinition.ofReport(
    BiReportDefinition(
      period: report.period,
      filters: report.filters,
      printStyle: report.printStyle,
      pages: [
        for (final p in report.pages)
          p.withVisuals([
            for (final v in p.visuals)
              if (v.metricId == null || readable(v.metricId!)) v,
          ]),
      ],
    ),
  );
}

class InMemoryBiViewRepository implements BiViewRepository {
  InMemoryBiViewRepository({
    this.canManage = true,
    this.reportsEnabled = true,
    this.readable,
    this.limits = const BiReportLimits(),
  });

  /// Whether the reader may write team views: workspaceSettings or
  /// designDocuments, beside viewAnalytics.
  bool canManage;

  /// Whether the report designer is on (the server's `biReportDesigner` gate).
  bool reportsEnabled;

  /// The metrics this reader may read now; null: every one.
  Set<String>? readable;

  /// The space's report limits (`bi.report_max_*`).
  BiReportLimits limits;

  final _views = <({String workspaceId, BiSavedView view})>[];
  final _requests = <String, ({String digest, String viewId})>{};
  var _next = 1;

  bool _readable(String metric) => readable?.contains(metric) ?? true;

  /// [view] as this reader receives it.
  BiSavedView _forReader(BiSavedView view) {
    final definition = view.definition;
    if (definition == null) return view;
    final withheld = _metricsOf(definition).where((m) => !_readable(m)).length;
    return BiSavedView(
      id: view.id,
      scope: view.scope,
      name: view.name,
      definition: _definitionFor(definition, _readable),
      isDefault: view.isDefault,
      revision: view.revision,
      mine: view.mine,
      withheld: withheld,
    );
  }

  /// Places [view] as an earlier server stored it, without today's write
  /// rules: a card of a retired metric, a figure saved at an older version.
  void addStored(String workspaceId, BiSavedView view) =>
      _views.add((workspaceId: workspaceId, view: view));

  @override
  Future<List<BiSavedView>> list(String workspaceId) async => [
    for (final e in _views)
      if (e.workspaceId == workspaceId) _forReader(e.view),
  ];

  @override
  Future<BiSavedView> save(
    String workspaceId, {
    String? id,
    required BiViewScope scope,
    required String name,
    required BiViewDefinition definition,
    required int expectedRevision,
    String? requestId,
  }) async {
    final digest = jsonEncode([
      id,
      scope.name,
      name.trim(),
      definition.toJson(),
      expectedRevision,
    ]);
    if (_replay(requestId, digest) case final again?) return again;
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 80) {
      throw const BiViewRefused(BiViewFailure.invalid);
    }
    if (scope == BiViewScope.workspace && !canManage) {
      throw const BiViewRefused(BiViewFailure.forbidden);
    }
    _checkMetrics(definition);
    final i = id == null ? -1 : _views.indexWhere((e) => e.view.id == id);
    if (id != null && i < 0) throw const BiViewRefused(BiViewFailure.forbidden);
    final old = i < 0 ? null : _views[i].view;
    if (old != null && old.scope != scope) {
      throw const BiViewRefused(BiViewFailure.invalid);
    }
    if (old?.definition case final stored?
        when _metricsOf(stored).any((m) => !_readable(m))) {
      throw const BiViewRefused(BiViewFailure.forbidden);
    }
    if (expectedRevision != (old?.revision ?? 0)) {
      throw const BiViewRefused(BiViewFailure.stale);
    }
    _checkReport(old, definition);
    _checkName(workspaceId, scope, id, trimmed);
    final view = BiSavedView(
      id: id ?? 'view-${_next++}',
      scope: scope,
      name: trimmed,
      definition: definition,
      isDefault: old?.isDefault ?? false,
      revision: (old?.revision ?? 0) + 1,
      mine: true,
    );
    final entry = (workspaceId: workspaceId, view: view);
    if (i < 0) {
      _views.add(entry);
    } else {
      _views[i] = entry;
    }
    if (requestId != null) {
      _requests[requestId] = (digest: digest, viewId: view.id);
    }
    return _forReader(view);
  }

  /// The answer to an earlier write under [requestId]: the same write
  /// again is answered once more, another one under its id is refused.
  BiSavedView? _replay(String? requestId, String digest) {
    final done = requestId == null ? null : _requests[requestId];
    if (done == null) return null;
    if (done.digest != digest) throw const BiViewRefused(BiViewFailure.invalid);
    final again = _views.where((e) => e.view.id == done.viewId).firstOrNull;
    if (again == null) throw const BiViewRefused(BiViewFailure.forbidden);
    return _forReader(again.view);
  }

  /// Another view of the same scope already has [name].
  void _checkName(
    String workspaceId,
    BiViewScope scope,
    String? id,
    String name,
  ) {
    if (_views.any(
      (e) =>
          e.workspaceId == workspaceId &&
          e.view.scope == scope &&
          e.view.id != id &&
          e.view.name.toLowerCase() == name.toLowerCase(),
    )) {
      throw const BiViewRefused(BiViewFailure.nameTaken);
    }
  }

  /// Every figure is a registered metric at its current version, and one
  /// this writer may read.
  void _checkMetrics(BiViewDefinition definition) {
    final report = definition.report;
    final versions = <String, int>{
      if (report == null)
        for (final c in definition.cards) c: definition.savedVersion(c)
      else
        for (final p in report.pages)
          for (final v in p.visuals) ?v.metricId: v.metricVersion,
    };
    for (final MapEntry(key: metric, value: version) in versions.entries) {
      final known = kpiDefinitionOf(metric);
      if (known == null) throw const BiViewRefused(BiViewFailure.invalid);
      if (known.version != version) {
        throw const BiViewRefused(BiViewFailure.unsupported);
      }
      if (!_readable(metric)) {
        throw const BiViewRefused(BiViewFailure.forbidden);
      }
    }
  }

  /// A report is written only with the designer on and within the space's
  /// limits, and a v1 writer never overwrites a report: it would erase what
  /// it cannot read.
  void _checkReport(BiSavedView? old, BiViewDefinition definition) {
    if ((definition.report != null && !reportsEnabled) ||
        (old?.definition?.report != null && definition.report == null)) {
      throw const BiViewRefused(BiViewFailure.unsupported);
    }
    if (definition.report case final r? when !limits.admits(r)) {
      throw const BiViewRefused(BiViewFailure.invalid);
    }
  }

  @override
  Future<void> delete(
    String workspaceId,
    String id,
    int expectedRevision,
  ) async {
    final i = _views.indexWhere((e) => e.view.id == id);
    if (i < 0) throw const BiViewRefused(BiViewFailure.forbidden);
    final v = _views[i].view;
    if (v.scope == BiViewScope.workspace && !canManage) {
      throw const BiViewRefused(BiViewFailure.forbidden);
    }
    if (v.revision != expectedRevision) {
      throw const BiViewRefused(BiViewFailure.stale);
    }
    _views.removeAt(i);
  }

  @override
  Future<void> setDefault(
    String workspaceId,
    BiViewScope scope,
    String? id,
  ) async {
    if (scope == BiViewScope.workspace && !canManage) {
      throw const BiViewRefused(BiViewFailure.forbidden);
    }
    if (id != null &&
        !_views.any((e) => e.view.id == id && e.view.scope == scope)) {
      throw const BiViewRefused(BiViewFailure.forbidden);
    }
    for (final (i, e) in _views.indexed) {
      if (e.workspaceId != workspaceId || e.view.scope != scope) continue;
      final v = e.view;
      _views[i] = (
        workspaceId: e.workspaceId,
        view: BiSavedView(
          id: v.id,
          scope: v.scope,
          name: v.name,
          definition: v.definition,
          isDefault: v.id == id,
          revision: v.revision,
          mine: v.mine,
        ),
      );
    }
  }
}

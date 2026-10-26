// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1923 C — saved Web-BI views: a name and a bounded definition (the
// query context and the cards, in order), private or shared with the
// workspace. A definition is a question, never an answer: no figures, no
// rights. Opening one checks it against what exists and what this reader
// may see NOW, and says what it had to leave out instead of silently
// showing something else.
//
// Pure Dart.
library;

import 'package:meta/meta.dart';

import 'bi_query.dart';
import 'bi_report_definition.dart';
import 'kpi_contract.dart';

export 'bi_view_memory.dart';

enum BiViewScope {
  private,
  workspace;

  static BiViewScope? fromWire(Object? v) =>
      values.where((s) => s.name == v).firstOrNull;
}

/// The stored definition: `{v: 1, query: {...}, cards: [...], metrics:
/// {id: version}}`, or a v2
/// report (#2579, [report]) whose period and first page are also exposed as
/// [query] and [cards], so every place that opens a view keeps working.
class BiViewDefinition {
  const BiViewDefinition({
    this.query = const {},
    this.cards = const [],
    this.metricVersions = const {},
    this.report,
  });

  /// A v2 report as a definition: each visual names its own version.
  factory BiViewDefinition.ofReport(BiReportDefinition report) =>
      BiViewDefinition(
        query: report.period.toQuery(),
        cards: report.firstPageCards,
        metricVersions: {
          for (final v in report.pages.first.visuals)
            ?v.metricId: v.metricVersion,
        },
        report: report,
      );

  /// Set for a v2 definition; null for v1.
  final BiReportDefinition? report;

  /// The address parameters of the query (see [BiQueryContext.toQuery]).
  final Map<String, String> query;

  /// Module ids, in display order; empty means every module.
  final List<String> cards;

  /// The metric version each card was saved with. A card it does
  /// not name was saved before versions were recorded, when every metric
  /// was at version 1.
  final Map<String, int> metricVersions;

  /// The version [card] was saved with.
  int savedVersion(String card) => metricVersions[card] ?? 1;

  static const version = 1;

  /// The largest definition the server stores (2 KB, the metric versions
  /// apart) and reads back.
  static const maxBytes = 2048;
  static const maxCards = 20;

  /// [context] as a definition: its cards apart, the rest as address
  /// parameters.
  factory BiViewDefinition.of(BiQueryContext context) => BiViewDefinition(
    query: context.toQuery()..remove('cards'),
    cards: context.cards,
    metricVersions: {
      for (final c in context.cards)
        if (kpiDefinitionOf(c) case final d?) c: d.version,
    },
  );

  Map<String, Object> toJson() =>
      report?.toJson() ??
      {
        'v': version,
        'query': query,
        'cards': cards,
        if (metricVersions.isNotEmpty) 'metrics': metricVersions,
      };

  /// Parses a stored definition; null when it is not one this client
  /// understands (another version, a malformed shape). Untrusted input:
  /// nothing is guessed.
  static BiViewDefinition? fromJson(Object? json) {
    if (biReportReader(json)?.raw('v') == BiReportDefinition.version) {
      final report = BiReportDefinition.fromJson(json);
      return report == null ? null : BiViewDefinition.ofReport(report);
    }
    if (json is! Map || json['v'] != version) return null;
    final query = json['query'] ?? const <String, Object?>{};
    final cards = json['cards'] ?? const <Object?>[];
    final versions = _versions(biReportReader(json)?.raw('metrics'));
    if (query is! Map || cards is! List || cards.length > maxCards) {
      return null;
    }
    if (versions == null) return null;
    final q = <String, String>{};
    for (final e in query.entries) {
      if (e.key is! String || e.value is! String) return null;
      q[e.key as String] = e.value as String;
    }
    final c = <String>[];
    for (final x in cards) {
      if (x is! String) return null;
      c.add(x);
    }
    return BiViewDefinition(query: q, cards: c, metricVersions: versions);
  }

  /// `{id: version}` as stored, or null when it is not one (untrusted).
  static Map<String, int>? _versions(Object? raw) {
    if (raw == null) return const {};
    if (raw is! Map || raw.length > maxCards) return null;
    final out = <String, int>{};
    for (final MapEntry(:key, :value) in raw.entries) {
      if (key is! String || value is! int || value < 1 || value > 99) {
        return null;
      }
      out[key] = value;
    }
    return out;
  }
}

/// What saving [open] over itself writes: a report stays the report it is
/// (its editor changes it); a v1 view takes the analysis on screen.
BiViewDefinition biSavedDefinition(BiSavedView open, BiQueryContext query) =>
    open.definition?.report != null
    ? open.definition!
    : BiViewDefinition.of(query);

class BiSavedView {
  /// The longest view name (`bi_view_save` refuses a longer one).
  static const maxName = 80;

  const BiSavedView({
    required this.id,
    required this.scope,
    required this.name,
    required this.definition,
    required this.isDefault,
    required this.revision,
    required this.mine,
    this.withheld = 0,
  });

  final String id;
  final BiViewScope scope;
  final String name;

  /// Null when the stored definition is not one this client reads.
  final BiViewDefinition? definition;
  final bool isDefault;
  final int revision;

  /// Saved by the reader.
  final bool mine;

  /// How many of the saved figures the server left out of [definition]
  /// because this reader may not read them now: their ids never reach this
  /// device, and a view left with none of its figures is not "every card".
  final int withheld;

  /// Opening this view for a reader who may see [visible] now.
  BiViewCheck check(Set<String> visible) =>
      checkView(definition, visible, withheld: withheld);

  /// The same view at another [revision] (an explicit save over a newer one).
  BiSavedView atRevision(int revision) => BiSavedView(
    id: id,
    scope: scope,
    name: name,
    definition: definition,
    isDefault: isDefault,
    revision: revision,
    mine: mine,
    withheld: withheld,
  );

  static BiSavedView? fromJson(Map<String, dynamic> json) {
    final scope = BiViewScope.fromWire(json['scope']);
    final id = json['id'], name = json['name'], revision = json['revision'];
    final withheld = biReportReader(json)?.raw('withheld') ?? 0;
    if (scope == null || id is! String || name is! String || revision is! num) {
      return null;
    }
    if (withheld is! num || withheld < 0) return null;
    return BiSavedView(
      id: id,
      scope: scope,
      name: name,
      definition: BiViewDefinition.fromJson(json['definition']),
      isDefault: json['is_default'] == true,
      revision: revision.toInt(),
      mine: json['mine'] == true,
      withheld: withheld.toInt(),
    );
  }
}

/// The view a bare /bi opens: the reader's own default, else the
/// workspace's, else none (the product standard).
BiSavedView? defaultView(List<BiSavedView> views) =>
    views
        .where((v) => v.scope == BiViewScope.private && v.mine && v.isDefault)
        .firstOrNull ??
    views
        .where((v) => v.scope == BiViewScope.workspace && v.isDefault)
        .firstOrNull;

/// What opening a definition yields for this reader.
class BiViewCheck {
  const BiViewCheck({
    required this.query,
    required this.unavailableCards,
    required this.unreadable,
    this.incompatibleCards = const [],
  });

  /// The parsed context with the cards that remain (in the saved
  /// order), or null when it was refused.
  final BiQueryContext? query;

  /// Cards that no longer exist or that this reader may not see.
  final List<String> unavailableCards;

  /// Cards saved for another version of their metric: the figure
  /// would mean something else now, so they are left out, never shown
  /// under the old name.
  final List<String> incompatibleCards;

  /// The definition could not be read at all (version, shape).
  final bool unreadable;

  bool get complete =>
      !unreadable &&
      query != null &&
      unavailableCards.isEmpty &&
      incompatibleCards.isEmpty;
}

/// Checks [definition] against the modules [visible] to this reader now.
/// Callers open a stored view through [BiSavedView.check].
/// [withheld] figures the server already left out count as unavailable: a
/// view left with no card of its own is refused, never widened to "all".
@visibleForTesting
BiViewCheck checkView(
  BiViewDefinition? definition,
  Set<String> visible, {
  int withheld = 0,
}) {
  if (definition == null) {
    return const BiViewCheck(
      query: null,
      unavailableCards: [],
      unreadable: true,
    );
  }
  bool current(String c) =>
      definition.savedVersion(c) == (kpiDefinitionOf(c)?.version ?? 1);
  final kept = [
    for (final c in definition.cards)
      if (visible.contains(c) && current(c)) c,
  ];
  // Every card gone is not "all cards": the view is then refused below. A
  // report's page names its cards; one with none is never every card.
  final query =
      (definition.cards.isNotEmpty ||
              withheld > 0 ||
              definition.report != null) &&
          kept.isEmpty
      ? null
      : BiQueryContext.tryParse(definition.query)?.copyWith(cards: kept);
  return BiViewCheck(
    query: query,
    unavailableCards: [
      for (final c in definition.cards)
        if (!visible.contains(c)) c,
    ],
    incompatibleCards: [
      for (final c in definition.cards)
        if (visible.contains(c) && !current(c)) c,
    ],
    unreadable: false,
  );
}

/// Why the server refused a view write.
enum BiViewFailure {
  /// Someone saved the view since it was read (40001).
  stale,

  /// Not the reader's to change, a team view without the right, or a view
  /// holding figures this reader may not read (save a copy instead).
  forbidden,

  /// Another view of the same scope has that name.
  nameTaken,

  /// A malformed name or definition.
  invalid,

  /// A report (v2) this writer may not store: the report designer is off,
  /// or the writer is an older client that would erase what it cannot read.
  unsupported,
}

class BiViewRefused implements Exception {
  const BiViewRefused(this.failure);

  final BiViewFailure failure;

  @override
  String toString() => 'BiViewRefused(${failure.name})';
}

/// Saved views, server side. Every call is authorized there.
abstract interface class BiViewRepository {
  /// The reader's private views and the workspace's team views.
  Future<List<BiSavedView>> list(String workspaceId);

  /// Creates ([id] null, [expectedRevision] 0) or updates a view. The same
  /// [requestId] with the same write answers that write again (a retry after
  /// a lost answer is not a second revision); with another write it is
  /// refused ([BiViewFailure.invalid]).
  Future<BiSavedView> save(
    String workspaceId, {
    String? id,
    required BiViewScope scope,
    required String name,
    required BiViewDefinition definition,
    required int expectedRevision,
    String? requestId,
  });

  Future<void> delete(String workspaceId, String id, int expectedRevision);

  /// The reader's own default ([BiViewScope.private]) or the team default
  /// ([BiViewScope.workspace]); null clears it.
  Future<void> setDefault(String workspaceId, BiViewScope scope, String? id);
}

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

import 'bi_query.dart';

enum BiViewScope {
  private,
  workspace;

  static BiViewScope? fromWire(Object? v) =>
      values.where((s) => s.name == v).firstOrNull;
}

/// The stored definition: `{v: 1, query: {...}, cards: [...]}`.
class BiViewDefinition {
  const BiViewDefinition({this.query = const {}, this.cards = const []});

  /// The address parameters of the query (see [BiQueryContext.toQuery]).
  final Map<String, String> query;

  /// Module ids, in display order; empty means every module.
  final List<String> cards;

  static const version = 1;

  /// The largest definition the server stores (2 KB) and reads back.
  static const maxBytes = 2048;
  static const maxCards = 20;

  /// [context] as a definition: its cards apart, the rest as address
  /// parameters.
  factory BiViewDefinition.of(BiQueryContext context) => BiViewDefinition(
    query: context.toQuery()..remove('cards'),
    cards: context.cards,
  );

  Map<String, Object> toJson() => {
    'v': version,
    'query': query,
    'cards': cards,
  };

  /// Parses a stored definition; null when it is not one this client
  /// understands (another version, a malformed shape). Untrusted input:
  /// nothing is guessed.
  static BiViewDefinition? fromJson(Object? json) {
    if (json is! Map || json['v'] != version) return null;
    final query = json['query'] ?? const <String, Object?>{};
    final cards = json['cards'] ?? const <Object?>[];
    if (query is! Map || cards is! List || cards.length > maxCards) {
      return null;
    }
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
    return BiViewDefinition(query: q, cards: c);
  }
}

class BiSavedView {
  const BiSavedView({
    required this.id,
    required this.scope,
    required this.name,
    required this.definition,
    required this.isDefault,
    required this.revision,
    required this.mine,
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

  static BiSavedView? fromJson(Map<String, dynamic> json) {
    final scope = BiViewScope.fromWire(json['scope']);
    final id = json['id'], name = json['name'], revision = json['revision'];
    if (scope == null || id is! String || name is! String || revision is! num) {
      return null;
    }
    return BiSavedView(
      id: id,
      scope: scope,
      name: name,
      definition: BiViewDefinition.fromJson(json['definition']),
      isDefault: json['is_default'] == true,
      revision: revision.toInt(),
      mine: json['mine'] == true,
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
  });

  /// The parsed context with the cards that remain (in the saved
  /// order), or null when it was refused.
  final BiQueryContext? query;

  /// Cards that no longer exist or that this reader may not see.
  final List<String> unavailableCards;

  /// The definition could not be read at all (version, shape).
  final bool unreadable;

  bool get complete => !unreadable && query != null && unavailableCards.isEmpty;
}

/// Checks [definition] against the modules [visible] to this reader now.
BiViewCheck checkView(BiViewDefinition? definition, Set<String> visible) {
  if (definition == null) {
    return const BiViewCheck(
      query: null,
      unavailableCards: [],
      unreadable: true,
    );
  }
  final kept = [
    for (final c in definition.cards)
      if (visible.contains(c)) c,
  ];
  // Every card gone is not "all cards": the view is then refused below.
  final query = definition.cards.isNotEmpty && kept.isEmpty
      ? null
      : BiQueryContext.tryParse(definition.query)?.copyWith(cards: kept);
  return BiViewCheck(
    query: query,
    unavailableCards: [
      for (final c in definition.cards)
        if (!visible.contains(c)) c,
    ],
    unreadable: false,
  );
}

/// Why the server refused a view write.
enum BiViewFailure {
  /// Someone saved the view since it was read (40001).
  stale,

  /// Not the reader's to change, or a team view without the right.
  forbidden,

  /// Another view of the same scope has that name.
  nameTaken,

  /// A malformed name or definition.
  invalid,
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

  /// Creates ([id] null, [expectedRevision] 0) or updates a view.
  Future<BiSavedView> save(
    String workspaceId, {
    String? id,
    required BiViewScope scope,
    required String name,
    required BiViewDefinition definition,
    required int expectedRevision,
  });

  Future<void> delete(String workspaceId, String id, int expectedRevision);

  /// The reader's own default ([BiViewScope.private]) or the team default
  /// ([BiViewScope.workspace]); null clears it.
  Future<void> setDefault(String workspaceId, BiViewScope scope, String? id);
}

/// The views in memory, under the server's rules (demonstration, tests).
class InMemoryBiViewRepository implements BiViewRepository {
  InMemoryBiViewRepository({this.canManage = true});

  /// Whether the reader holds workspaceSettings (team views).
  bool canManage;
  final _views = <({String workspaceId, BiSavedView view})>[];
  var _next = 1;

  @override
  Future<List<BiSavedView>> list(String workspaceId) async => [
    for (final e in _views)
      if (e.workspaceId == workspaceId) e.view,
  ];

  @override
  Future<BiSavedView> save(
    String workspaceId, {
    String? id,
    required BiViewScope scope,
    required String name,
    required BiViewDefinition definition,
    required int expectedRevision,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 80) {
      throw const BiViewRefused(BiViewFailure.invalid);
    }
    if (scope == BiViewScope.workspace && !canManage) {
      throw const BiViewRefused(BiViewFailure.forbidden);
    }
    final i = id == null ? -1 : _views.indexWhere((e) => e.view.id == id);
    if (id != null && i < 0) throw const BiViewRefused(BiViewFailure.forbidden);
    final old = i < 0 ? null : _views[i].view;
    if (old != null && old.scope != scope) {
      throw const BiViewRefused(BiViewFailure.invalid);
    }
    if (expectedRevision != (old?.revision ?? 0)) {
      throw const BiViewRefused(BiViewFailure.stale);
    }
    if (_views.any(
      (e) =>
          e.workspaceId == workspaceId &&
          e.view.scope == scope &&
          e.view.id != id &&
          e.view.name.toLowerCase() == trimmed.toLowerCase(),
    )) {
      throw const BiViewRefused(BiViewFailure.nameTaken);
    }
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
    return view;
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

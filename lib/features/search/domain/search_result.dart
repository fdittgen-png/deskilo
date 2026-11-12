// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3610 — what search finds: a page, an action or a record, and where it
// is. Pure Dart: the sources that fill it live with the app.

/// What a result is.
enum SearchKind { page, action, record }

/// Whose search it is: the account, the server and the workspace. An answer
/// or a recent item belongs to one and is never shown under another.
typedef SearchScope = ({String account, String server, String workspace});

/// One thing search offers.
final class SearchResult {
  const SearchResult({
    required this.id,
    required this.kind,
    required this.source,
    required this.title,
    required this.where,
    this.route,
  });

  /// Stable across searches (`page:drawer-invoices`, `invoice:<id>`).
  final String id;
  final SearchKind kind;

  /// The source that found it: re-asked whether it may still be offered.
  final String source;
  final String title;

  /// Where it is: the navigation group, the customer an invoice is for.
  final String where;

  /// The address that opens it (a record); a page or an action is opened
  /// by its source.
  final String? route;

  @override
  bool operator ==(Object other) => other is SearchResult && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// One kind of record the reader may find (members, invoices, …).
abstract interface class SearchSource {
  /// The [SearchResult.source] of its results.
  String get id;

  /// Up to a few results for [query].
  Future<List<SearchResult>> search(String query);
}

/// Whether every word of [query] is in one of [texts], whatever the case.
bool searchMatches(String query, Iterable<String?> texts) {
  final words = query.toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  if (words.isEmpty) return false;
  final hay = [
    for (final t in texts)
      if (t != null) t.toLowerCase(),
  ].join(' ');
  return words.every(hay.contains);
}

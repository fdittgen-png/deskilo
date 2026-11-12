// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3610 — the search window (Ctrl/⌘+K, or the bar's search button): one
// field, and what it finds — pages, actions and records — each saying what
// it is and where. Before anything is typed it lists the reader's recent
// items. What is offered is asked again on every build (a permission taken
// away while the window is open takes the page, the action or the record
// source with it) and once more when a result is opened. Typing is
// debounced; an older answer never replaces a newer one.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../application/search_run.dart';
import '../domain/search_result.dart';
import '../providers/search_providers.dart';

/// A page or an action search offers, and how it is opened.
class SearchOffer {
  const SearchOffer(this.result, this.open);

  final SearchResult result;
  final VoidCallback open;
}

/// What the reader may find now: the pages and actions, and the record
/// sources.
typedef SearchOffers = ({List<SearchOffer> fixed, List<SearchSource> sources});

/// How long typing rests before the records are asked.
const Duration searchDebounce = Duration(milliseconds: 250);

/// Opens the search window over [context].
Future<void> showSearchPalette(
  BuildContext context, {
  required SearchOffers Function(BuildContext context, WidgetRef ref) offers,
  required ValueChanged<String> openRoute,
}) => showDialog<void>(
  context: context,
  builder: (_) => SearchPalette(offers: offers, openRoute: openRoute),
);

class SearchPalette extends ConsumerStatefulWidget {
  const SearchPalette({
    required this.offers,
    required this.openRoute,
    super.key,
  });

  final SearchOffers Function(BuildContext context, WidgetRef ref) offers;

  /// Opens a record's address.
  final ValueChanged<String> openRoute;

  @override
  ConsumerState<SearchPalette> createState() => _SearchPaletteState();
}

class _SearchPaletteState extends ConsumerState<SearchPalette> {
  final _text = TextEditingController();
  final _run = SearchRun();
  Timer? _wait;
  List<SearchResult> _records = const [];
  SearchOffers _offers = (fixed: const [], sources: const []);
  int _selected = 0;
  List<SearchResult> _shown = const [];

  @override
  void dispose() {
    _wait?.cancel();
    _run.discard();
    _text.dispose();
    super.dispose();
  }

  void _typed(String _) {
    _wait?.cancel();
    setState(() {
      _selected = 0;
      _records = const [];
    });
    final query = _text.text.trim();
    if (query.isEmpty) {
      _run.discard();
      return;
    }
    _wait = Timer(searchDebounce, () => unawaited(_ask(query)));
  }

  Future<void> _ask(String query) async {
    final scope = ref.read(searchScopeProvider);
    if (scope == null) return;
    final found = await _run.run(
      scope,
      query,
      _offers.sources,
      currentScope: () => mounted ? ref.read(searchScopeProvider) : null,
    );
    if (found == null || !mounted || _text.text.trim() != query) return;
    setState(() => _records = found);
  }

  void _open(SearchResult result) {
    // Asked again now: what may be opened is what is offered this frame.
    final fixed = {for (final o in _offers.fixed) o.result.id: o};
    final sources = {for (final s in _offers.sources) s.id};
    final offer = fixed[result.id];
    final route = result.route;
    if (offer == null && (route == null || !sources.contains(result.source))) {
      return;
    }
    ref.read(searchRecentsProvider.notifier).opened(result);
    Navigator.of(context).pop();
    if (offer != null) {
      offer.open();
    } else {
      widget.openRoute(route!);
    }
  }

  List<SearchResult> _results() {
    final fixed = [for (final o in _offers.fixed) o.result];
    final sources = {for (final s in _offers.sources) s.id};
    bool offered(SearchResult r) => r.kind == SearchKind.record
        ? sources.contains(r.source)
        : fixed.contains(r);
    final query = _text.text.trim();
    if (query.isEmpty) {
      // Recent items, as they are offered now: a page or an action by its
      // current words, a record only while its source may be asked.
      return [
        for (final r in ref.watch(searchRecentsProvider))
          if (offered(r) && r.kind == SearchKind.record)
            r
          else if (offered(r))
            fixed[fixed.indexOf(r)],
      ];
    }
    final recent = ref.watch(searchRecentsProvider);
    int rank(SearchResult r) {
      final i = recent.indexOf(r);
      return i < 0 ? recent.length : i;
    }

    return [
      for (final r in fixed)
        if (searchMatches(query, [r.title, r.where])) r,
      ..._records.where(offered),
    ]..sort((a, b) => rank(a).compareTo(rank(b)));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || _shown.isEmpty) return KeyEventResult.ignored;
    final by = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => 1,
      LogicalKeyboardKey.arrowUp => -1,
      _ => 0,
    };
    if (by == 0) return KeyEventResult.ignored;
    setState(() => _selected = (_selected + by).clamp(0, _shown.length - 1));
    return KeyEventResult.handled;
  }

  IconData _icon(SearchKind kind) => switch (kind) {
    SearchKind.page => Icons.article_outlined,
    SearchKind.action => Icons.bolt_outlined,
    SearchKind.record => Icons.description_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.listen(searchScopeProvider, (_, _) {
      // Another account, server or workspace: nothing found before stays.
      _run.discard();
      setState(() => _records = const []);
    });
    _offers = widget.offers(context, ref);
    final shown = _shown = _results();
    if (_selected >= shown.length) _selected = 0;
    final query = _text.text.trim();
    return Dialog(
      key: const ValueKey('search-palette'),
      alignment: Alignment.topCenter,
      // Tab goes field first, then the results in their order, however far
      // the list has scrolled.
      child: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Focus(
                canRequestFocus: false,
                skipTraversal: true,
                onKeyEvent: _onKey,
                child: TextField(
                  key: const ValueKey('search-field'),
                  controller: _text,
                  autofocus: true,
                  textInputAction: TextInputAction.go,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.searchHint,
                    labelText: l10n.searchTitle,
                  ),
                  onChanged: _typed,
                  onSubmitted: (_) {
                    if (shown.isNotEmpty) _open(shown[_selected]);
                  },
                ),
              ),
            ),
            if (query.isEmpty && shown.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  l10n.searchRecent,
                  key: const ValueKey('search-recent'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            if (query.isNotEmpty && shown.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.searchNothing(query),
                  key: const ValueKey('search-nothing'),
                ),
              ),
            Flexible(
              // Every result built (a short list): Tab reaches each one
              // however far the list has scrolled.
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final (i, r) in shown.indexed)
                      ListTile(
                        key: ValueKey('search-result-${r.id}'),
                        selected: i == _selected,
                        leading: Icon(_icon(r.kind)),
                        title: Text(r.title),
                        subtitle: Text(r.where),
                        onTap: () => _open(r),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

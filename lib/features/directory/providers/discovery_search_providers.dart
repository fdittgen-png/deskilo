// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2832 — what a person asked of Discover, kept while the app runs: the words,
// the kind, the facts asked for, the business selected and how far the list
// was scrolled. The screen reads it when it opens and writes it when the
// person changes it, so a detail page and Back, a tab and back, or a window
// resized across the split width bring the search back as it was. It is the
// session's: another account starts with an empty search.
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/session/session_source.dart';
import '../domain/discovery_paging.dart';
import '../domain/public_workspace.dart';

part 'discovery_search_providers.g.dart';

@immutable
class DiscoverySearchState {
  const DiscoverySearchState({
    this.filter = const DiscoveryFilter(''),
    this.selected,
  });

  final DiscoveryFilter filter;
  final PublicWorkspace? selected;
}

@Riverpod(keepAlive: true)
class DiscoverySearch extends _$DiscoverySearch {
  /// How far the list was scrolled: a plain field, read once when the list
  /// is built, so a scroll never rebuilds anything.
  double _scroll = 0;

  @override
  DiscoverySearchState build() {
    ref.watch(sessionStateProvider).value;
    _scroll = 0;
    return const DiscoverySearchState();
  }

  /// Where the list was left.
  double scrolledTo() => _scroll;

  /// The list was scrolled to [offset].
  void scrolled(double offset) => _scroll = offset;

  /// A new filter is a new listing: the selection and the scroll start again.
  void filtered(DiscoveryFilter filter) {
    _scroll = 0;
    state = DiscoverySearchState(filter: filter);
  }

  void select(PublicWorkspace? workspace) =>
      state = DiscoverySearchState(filter: state.filter, selected: workspace);
}

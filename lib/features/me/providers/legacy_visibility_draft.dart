// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2558 — the legacy personal account being looked at, and the one change
// being made to it. A change belongs to the account it was made on: moving
// to another account first saves or discards it, so a draft never travels
// to another source.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/visibility.dart';

/// The account shown ([source], null: the first one) and the unsaved
/// [choice] for its [field], if any.
class LegacyDraft {
  const LegacyDraft({this.source, this.field, this.choice});

  final String? source;
  final VisibilityField? field;
  final FieldAudience? choice;

  /// Whether a change waits to be saved or discarded.
  bool get dirty => field != null && choice != null;
}

final legacyVisibilityDraftProvider =
    NotifierProvider.autoDispose<_LegacyDraftNotifier, LegacyDraft>(
  _LegacyDraftNotifier.new,
);

class _LegacyDraftNotifier extends Notifier<LegacyDraft> {
  @override
  LegacyDraft build() => const LegacyDraft();

  /// Shows [source]; any change of the account shown before is dropped
  /// with it, never carried over.
  void select(String source) => state = LegacyDraft(source: source);

  /// Holds [choice] for [field] of [source], unsaved: one field at a time.
  void edit(String source, VisibilityField field, FieldAudience choice) =>
      state = LegacyDraft(source: source, field: field, choice: choice);

  /// Drops the unsaved change; the account shown stays.
  void discard() => state = LegacyDraft(source: state.source);
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4448 -- where a till's layouts live: the draft being edited and the one published. Every write goes under a request id
// and the version the editor read; the server refuses a stale version (DKL10) and an invalid layout with its first
// problem (DKL02), as `till_layout_save_v1` and `till_layout_publish_v1` do.
import '../../../core/failure/app_failure.dart' show TypedRefusal;
import 'till_layout.dart';

/// Why a save or a publish was refused: another editor moved the version, or the layout breaks a rule (with the first
/// problem the server named), or something else the editor only reports.
enum TillLayoutRefusalKind { stale, invalid, other }

class TillLayoutRefused implements TypedRefusal {
  const TillLayoutRefused(this.kind, [this.reason = '']);

  final TillLayoutRefusalKind kind;

  /// The server's first problem (`outside_grid page 0 phone cell 1`), for an invalid layout.
  final String reason;

  @override
  String toString() => 'TillLayoutRefused(${kind.name} $reason)';
}

abstract interface class TillLayoutPort {
  /// The draft of [tillId], or null when none is being edited.
  Future<TillLayout?> draft(String workspaceId, String tillId);

  /// The layout [tillId] uses, or null: the till keeps its generated keys.
  Future<TillLayout?> published(String workspaceId, String tillId);

  /// Saves [layout] as the draft of [tillId] over the version the editor read (0: no draft yet); answers the new version.
  Future<int> save(String workspaceId, {required String requestId, required String tillId, required TillLayout layout, required int expectedVersion});

  /// Publishes the draft of [tillId] at the version the editor read; answers the published layout's version.
  Future<int> publish(String workspaceId, {required String requestId, required String tillId, required int expectedVersion});
}

// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3336 (0692) — whether the accounting connectors admit NEW work in this
// space: `active`, `servicing` (new work refused; history, revocation and the
// outcome of admitted work stay) or `retired`. The server decides and records
// who moved it and why; these are the transitions the screen offers, the same
// as the contract's, so it never offers a move the server would refuse.

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

enum CapabilityStateKind {
  active('active'),
  servicing('servicing'),
  retired('retired');

  const CapabilityStateKind(this.wire);
  final String wire;

  static CapabilityStateKind of(String? wire) => values.firstWhere(
    (v) => v.wire == wire,
    orElse: () => servicing, // an unknown state admits nothing
  );
}

/// The state as the server reports it.
class CapabilityState {
  const CapabilityState({
    required this.kind,
    this.derived = true,
    this.reason = '',
    this.changedAt,
  });

  factory CapabilityState.fromJson(Map<String, Object?> json) {
    final r = JsonReader(json, context: 'capability state');
    return CapabilityState(
      kind: CapabilityStateKind.of(r.stringOrNull('state')),
      derived: r.boolOr('derived', fallback: true),
      reason: r.stringOr('reason'),
      changedAt: r.dateTimeOrNull('changed_at'),
    );
  }

  final CapabilityStateKind kind;

  /// No operator decision is stored: the state follows the feature choice.
  final bool derived;
  final String reason;
  final DateTime? changedAt;
}

/// The moves out of [from] that the person may be offered: a manager moves
/// between active and servicing; retiring and reopening are the owner's.
List<CapabilityStateKind> capabilityMoves(
  CapabilityStateKind from, {
  required bool owner,
}) => switch (from) {
  CapabilityStateKind.active => const [CapabilityStateKind.servicing],
  CapabilityStateKind.servicing => [
    CapabilityStateKind.active,
    if (owner) CapabilityStateKind.retired,
  ],
  CapabilityStateKind.retired => [
    if (owner) CapabilityStateKind.servicing,
  ],
};

/// Whether moving [from] -> [to] needs a stated reason (retiring and
/// reopening do; the server refuses a blank one).
bool capabilityMoveNeedsReason(
  CapabilityStateKind from,
  CapabilityStateKind to,
) => from == CapabilityStateKind.retired || to == CapabilityStateKind.retired;

/// The longest reason the server keeps.
const capabilityReasonWidth = 300;

/// Why the server refused a move, as far as the screen words it.
enum CapabilityRefusal { unresolved, owner, switchedOff, other }

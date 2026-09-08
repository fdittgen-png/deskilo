// SPDX-License-Identifier: 0BSD

/// #1030 — the two membership refusals every workspace RPC shares.
///
/// `assert_active_member` (and every guard built on it) raises one of
/// these before it looks at the request itself: a booking, a message,
/// the day-end sweep all fail the same way when the caller's membership
/// is not active. Pinning the substrings here keeps the mapping in one
/// place, the way [WorkspaceClosedError] does for the calendar.
///
/// Both used to reach the member as "the seat may have just been
/// taken" — a race nobody can win, hiding the one thing an
/// administrator can actually fix.
abstract final class MembershipPausedError {
  /// Raised when the row exists but its status is not `active`.
  static const String serverSubstring = 'not an active member';
}

/// The caller holds no membership row in the workspace at all.
abstract final class NotAMemberError {
  static const String serverSubstring = 'not a member of this workspace';
}

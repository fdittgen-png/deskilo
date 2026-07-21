// SPDX-License-Identifier: 0BSD

/// Server-side error text raised by `assert_member_quota` (migration
/// 0031) when a booking would exceed the member's monthly half-day
/// entitlement (ceil(open_days × 2 × pct / 100) plus confirmed quota
/// extensions). The booking error mapping matches this substring —
/// pinned by test, like [WorkspaceClosedError] and
/// [BookingGranularityError].
abstract final class QuotaExceededError {
  static const String serverSubstring = 'half-day quota';
}

/// Server-side error text raised by the `enforce_reservation_limit`
/// trigger (migration 0044) when a booking would exceed the member's cap
/// on simultaneous open reservations. Pinned by test, like
/// [QuotaExceededError].
abstract final class ReservationLimitError {
  static const String serverSubstring = 'reservation limit';
}

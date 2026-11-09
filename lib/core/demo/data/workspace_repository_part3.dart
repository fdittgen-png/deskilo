// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'workspace_repository.dart';

// #2386 — part 3 of FakeWorkspaceRepository, split out of workspace_repository.dart so no
// file holds the whole class.
extension _FakeWorkspaceRepositoryPart3 on FakeWorkspaceRepository {

  Future<void> _clearWorkspaceEmblemImpl(String workspaceId) async {
    emblems.remove(workspaceId);
  }

  Future<Map<String, dynamic>> _setWorkspaceBrandingImpl(
    String workspaceId,
    Map<String, dynamic> delta,
  ) async {
    // The server merges into the row, so the fake starts from what the
    // workspace carries — not from an empty map, which would make a
    // reset of one key look like a reset of all of them.
    final stored = workspaces.where((w) => w.id == workspaceId).firstOrNull;
    final current = Map<String, dynamic>.from(
        brandings[workspaceId] ?? stored?.branding ?? const {});
    for (final e in delta.entries) {
      if (e.value == null) {
        current.remove(e.key);
      } else {
        current[e.key] = e.value;
      }
    }
    final mine = WorkspaceSymbol.of(current);
    if (mine != null &&
        symbolClashes(mine, [
          for (final w in workspaces)
            if (w.id != workspaceId) brandings[w.id] ?? w.branding,
        ])) {
      throw const WorkspaceSymbolTaken();
    }
    brandings[workspaceId] = current;
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i >= 0) workspaces[i] = workspaces[i].copyWith(branding: current);
    return current;
  }

  Future<Map<String, dynamic>> _fetchLexiconImpl(String workspaceId) async =>
      {for (final e in (lexicons[workspaceId] ?? {}).entries) e.key: e.value};

  Future<void> _setLexiconTermImpl(
    String workspaceId,
    String locale,
    String key,
    String? text,
  ) async {
    final byLocale = lexicons.putIfAbsent(workspaceId, () => {});
    final terms = byLocale.putIfAbsent(locale, () => {});
    if (text == null) {
      terms.remove(key);
    } else {
      terms[key] = text;
    }
  }

  Future<BookingPolicies> _fetchBookingPoliciesImpl(String workspaceId) async =>
      bookingPolicies[workspaceId] ?? const BookingPolicies();

  Future<void> _setBookingPolicyImpl(
    String workspaceId,
    String key, {
    required bool enabled,
  }) async {
    final p = bookingPolicies[workspaceId] ?? const BookingPolicies();
    bookingPolicies[workspaceId] = switch (key) {
      BookingPolicies.allowPastBookingsKey =>
        p.copyWith(allowPastBookings: enabled),
      // #634: grid_within_hours is read-only legacy — no writer.
      BookingPolicies.adminCheckOutKey => p.copyWith(adminCheckOut: enabled),
      _ => p,
    };
  }

  Future<void> _setSimultaneousReservationsImpl(
    String workspaceId,
    int value,
  ) async {
    final p = bookingPolicies[workspaceId] ?? const BookingPolicies();
    bookingPolicies[workspaceId] =
        p.copyWith(simultaneousReservations: value);
  }

  Future<void> _setBookingLimitImpl(
    String workspaceId,
    String key,
    int value,
  ) async {
    final p = bookingPolicies[workspaceId] ?? const BookingPolicies();
    bookingPolicies[workspaceId] = switch (key) {
      BookingPolicies.advanceHorizonDaysKey =>
        p.copyWith(advanceHorizonDays: value),
      BookingPolicies.minDurationMinutesKey =>
        p.copyWith(minDurationMinutes: value),
      BookingPolicies.maxDurationMinutesKey =>
        p.copyWith(maxDurationMinutes: value),
      _ => p,
    };
  }

  Future<void> _setLegendProfileImpl(
    String workspaceId,
    LegendProfile profile,
  ) async {
    final p = bookingPolicies[workspaceId] ?? const BookingPolicies();
    bookingPolicies[workspaceId] = p.copyWith(legendProfile: profile);
  }

  Future<void> _setOutsideHoursModeImpl(
    String workspaceId,
    OutsideHoursMode mode,
  ) async {
    final p = bookingPolicies[workspaceId] ?? const BookingPolicies();
    bookingPolicies[workspaceId] = p.copyWith(outsideHoursMode: mode);
  }

}

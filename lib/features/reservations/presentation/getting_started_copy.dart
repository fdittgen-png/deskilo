// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../l10n/app_localizations.dart';
import '../../workspace/presentation/widgets/workspace_readiness_card.dart';
import '../application/getting_started_hint.dart';

/// Localized wording for the existing hint model; it creates no business facts.
abstract final class GettingStartedCopy {
  static String standing(
    AppLocalizations l10n,
    MembershipStanding standing,
  ) => switch (standing) {
    MembershipStanding.owner =>
      l10n.gettingStartedStandingOwner,
    MembershipStanding.administrator =>
      l10n.gettingStartedStandingAdmin,
    _ => l10n.gettingStartedStandingMember,
  };

  static String reason(AppLocalizations l10n, GettingStartedHint hint) =>
      switch (hint.reason) {
        GettingStartedReason.readyToBook =>
          l10n.gettingStartedReadyToBook,
        GettingStartedReason.closedToday =>
          l10n.gettingStartedClosedToday,
        GettingStartedReason.noSpaces =>
          l10n.gettingStartedNoSpaces,
        GettingStartedReason.availabilityUnknown =>
          l10n.gettingStartedAvailabilityUnknown,
        GettingStartedReason.membershipUnknown =>
          l10n.gettingStartedMembershipUnknown,
        GettingStartedReason.booked =>
          l10n.gettingStartedBooked(
                bookingState(l10n, hint.booking!.state),
              ),
        GettingStartedReason.setupIncomplete => () {
          final area = hint.setupStep?.area;
          final step = area == null
              ? (l10n.readinessTitle)
              : readinessAreaLabel(l10n, area);
          return l10n.gettingStartedSetupIncomplete(step);
        }(),
        GettingStartedReason.loading ||
        GettingStartedReason.pendingAdmission => '',
      };

  static String booking(AppLocalizations l10n, BookingEvidence b) =>
      [if (b.spaceName.trim().isNotEmpty) b.spaceName,
        bookingState(l10n, b.state)].join(' · ');

  /// The real state name, in the reader's language; an unknown wire
  /// value is shown as it came rather than guessed at.
  static String bookingState(AppLocalizations l10n, String state) =>
      switch (state) {
        'reserved' => l10n.gettingStartedStateReserved,
        'checkedIn' => l10n.gettingStartedStateCheckedIn,
        'completed' => l10n.gettingStartedStateCompleted,
        'cancelled' => l10n.gettingStartedStateCancelled,
        'released' => l10n.gettingStartedStateReleased,
        _ => state,
      };
}

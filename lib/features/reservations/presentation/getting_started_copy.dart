// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../l10n/app_localizations.dart';
import '../application/getting_started_hint.dart';

/// Localized wording for the existing hint model; it creates no business facts.
abstract final class GettingStartedCopy {
  static String standing(
    AppLocalizations? l10n,
    MembershipStanding standing,
  ) => switch (standing) {
    MembershipStanding.owner =>
      l10n?.gettingStartedStandingOwner ??
          'You are an owner of this workspace.',
    MembershipStanding.administrator =>
      l10n?.gettingStartedStandingAdmin ?? 'You are an administrator here.',
    _ => l10n?.gettingStartedStandingMember ?? 'You are a member here.',
  };

  static String reason(AppLocalizations? l10n, GettingStartedHint hint) =>
      switch (hint.reason) {
        GettingStartedReason.readyToBook =>
          l10n?.gettingStartedReadyToBook ??
              'The workspace is open on this day. Pick a time and a space '
                  'on the plan — nothing is booked until you confirm.',
        GettingStartedReason.closedToday =>
          l10n?.gettingStartedClosedToday ??
              'The workspace is closed on the selected day. Choose another '
                  'day to see what is free.',
        GettingStartedReason.noSpaces =>
          l10n?.gettingStartedNoSpaces ??
              'Nothing can be booked here yet. Your membership shows what '
                  'your access includes.',
        GettingStartedReason.availabilityUnknown =>
          l10n?.gettingStartedAvailabilityUnknown ??
              'Availability could not be loaded. The help explains how '
                  'booking works here.',
        GettingStartedReason.membershipUnknown =>
          l10n?.gettingStartedMembershipUnknown ??
              'Your membership could not be loaded right now. The help '
                  'explains how this workspace works.',
        GettingStartedReason.booked =>
          l10n?.gettingStartedBooked(
                hint.booking!.id,
                bookingState(l10n, hint.booking!.state),
              ) ??
              'Your booking ${hint.booking!.id} is ${hint.booking!.state}.',
        GettingStartedReason.loading ||
        GettingStartedReason.pendingAdmission => '',
      };

  static String booking(AppLocalizations? l10n, BookingEvidence b) =>
      '${b.id} · ${bookingState(l10n, b.state)}';

  /// The real state name, in the reader's language; an unknown wire
  /// value is shown as it came rather than guessed at.
  static String bookingState(AppLocalizations? l10n, String state) =>
      switch (state) {
        'reserved' => l10n?.gettingStartedStateReserved ?? state,
        'checkedIn' => l10n?.gettingStartedStateCheckedIn ?? state,
        'completed' => l10n?.gettingStartedStateCompleted ?? state,
        'cancelled' => l10n?.gettingStartedStateCancelled ?? state,
        'released' => l10n?.gettingStartedStateReleased ?? state,
        _ => state,
      };
}

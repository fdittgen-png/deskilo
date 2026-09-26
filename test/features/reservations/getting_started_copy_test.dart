// SPDX-License-Identifier: AGPL-3.0-or-later
// #1654: uncertainty, admission and actual outcomes retain their meaning in copy.
import 'package:deskilo/features/reservations/application/getting_started_hint.dart';
import 'package:deskilo/features/reservations/presentation/getting_started_copy.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unknown membership never reads as a missing or completed task', () {
    const hint = GettingStartedHint(reason: GettingStartedReason.membershipUnknown,
      action: GettingStartedAction.openHelp);
    expect(GettingStartedCopy.reason(null, hint),
      'Your membership could not be loaded right now. The help explains how this workspace works.');
    expect(GettingStartedCopy.reason(lookupAppLocalizations(const Locale('en')), hint),
      GettingStartedCopy.reason(null, hint));
  });
  for (final language in ['en', 'fr', 'de', 'es', 'it']) {
    test('$language preserves waiting and actual booking evidence', () {
      final l10n = lookupAppLocalizations(Locale(language));
      for (final reason in [GettingStartedReason.loading, GettingStartedReason.pendingAdmission]) {
        expect(GettingStartedCopy.reason(l10n, GettingStartedHint(reason: reason)), isEmpty);
      }
      const evidence = BookingEvidence(id: 'reservation-42', state: 'checkedIn');
      final result = GettingStartedCopy.reason(l10n,
        const GettingStartedHint(reason: GettingStartedReason.booked, booking: evidence));
      expect(result, contains('reservation-42'));
      expect(result, contains(l10n.gettingStartedStateCheckedIn));
      expect(GettingStartedCopy.bookingState(l10n, 'unknown-state'), 'unknown-state');
      for (final reason in GettingStartedReason.values.where((r) =>
          r != GettingStartedReason.loading && r != GettingStartedReason.pendingAdmission && r != GettingStartedReason.booked)) {
        expect(GettingStartedCopy.reason(l10n, GettingStartedHint(reason: reason)), isNotEmpty);
      }
    });
  }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/booking_success_text.dart';

/// Announces a booking that SUCCEEDED (#663), so an attempt always ends
/// in an answer — the reservation or check-in, named and dated, or the
/// reason it was refused.
///
/// One call site per screen, because the alternative is what
/// `bookingErrorText` already had to be rescued from: the same block
/// pasted onto four screens, drifting apart. The message itself is built
/// in `domain/`, which is pure Dart; only the snack lives here.
void announceBooking(
  BuildContext context,
  AppLocalizations? l10n, {
  required bool checkedIn,
  required DateTime start,
  required DateTime end,
  String? spaceName,
  VoidCallback? onOpen,
}) {
  AppSnack.success(
    context,
    bookingSuccessText(
      l10n,
      Localizations.localeOf(context).toLanguageTag(),
      checkedIn: checkedIn,
      start: start,
      end: end,
      spaceName: spaceName,
    ),
    replace: true,
    // #1301 S3 — the answer is the reservation itself, one tap away,
    // with what can be done with it (check in, move, cancel) on its sheet.
    action: onOpen == null
        ? null
        : SnackBarAction(
            label: l10n?.bookingOpenDetails ?? 'Details',
            onPressed: onOpen,
          ),
  );
}

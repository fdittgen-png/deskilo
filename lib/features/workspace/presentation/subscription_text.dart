// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/i18n/app_format.dart';
import '../../../l10n/app_localizations.dart';

/// A member's subscription as a person reads it: a percentage, or — at 0,
/// a visitor who buys carnets (#1279) — "No subscription", never "0%".
String subscriptionText(AppLocalizations l10n, AppFormat format, int pct) =>
    pct == 0 ? l10n.memberNoSubscription : format.ratePercent(pct);

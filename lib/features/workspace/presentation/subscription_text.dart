// SPDX-License-Identifier: 0BSD
import '../../../l10n/app_localizations.dart';

/// A member's subscription as a person reads it: a percentage, or — at 0,
/// a visitor who buys carnets (#1279) — "No subscription", never "0%".
String subscriptionText(AppLocalizations? l10n, int pct) => pct == 0
    ? (l10n?.memberNoSubscription ?? 'No subscription')
    : (l10n?.percentValue(pct) ?? '$pct%');

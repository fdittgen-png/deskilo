// SPDX-License-Identifier: 0BSD
import '../../l10n/app_localizations.dart';

/// The PRODUCT's own word for [key], in whatever locale [l10n] carries.
///
/// The editor shows this beside the workspace's override, so an owner
/// can see what they are replacing — and for the locale being EDITED,
/// which is not necessarily the one the app is running in. Load another
/// locale's bundle with `AppLocalizations.delegate.load(locale)`.
///
/// It exists because `AppLocalizations` has 3 064 named getters and no
/// lookup by name: every `lexiconText` call site passes its own
/// fallback, so nothing central mapped a key to its default until now.
/// `lexicon_allow_list_test` pins an arm for every allow-listed key —
/// a missing one would show the owner a blank default beside the term
/// they are trying to rename.
String lexiconDefault(AppLocalizations? l10n, String key) => switch (key) {
      'legendFree' => l10n?.legendFree ?? 'Free',
      'legendReserved' => l10n?.legendReserved ?? 'Reserved',
      'legendOccupied' => l10n?.legendOccupied ?? 'Checked in',
      'legendMine' => l10n?.legendMine ?? 'Mine',
      'legendBlocked' => l10n?.legendBlocked ?? 'Blocked',
      'legendClosed' => l10n?.legendClosed ?? 'Closed day',
      'reserveClosedShort' => l10n?.reserveClosedShort ?? 'Closed',
      'spaceKindSeat' => l10n?.spaceKindSeat ?? 'Seat',
      'spaceKindDesk' => l10n?.spaceKindDesk ?? 'Desk',
      'spaceKindOffice' => l10n?.spaceKindOffice ?? 'Office',
      'spaceKindLevel' => l10n?.spaceKindLevel ?? 'Level',
      'levelDetail' => l10n?.levelDetail ?? 'Whole level',
      'deskDetail' => l10n?.deskDetail ?? 'Whole desk',
      'tabPlan' => l10n?.tabPlan ?? 'Plan',
      'tabCalendar' => l10n?.tabCalendar ?? 'Calendar',
      'tabEvents' => l10n?.tabEvents ?? 'Events',
      'tabMoney' => l10n?.tabMoney ?? 'Money',
      'directoryTitle' => l10n?.directoryTitle ?? 'Members',
      'messagesTitle' => l10n?.messagesTitle ?? 'Messages',
      'shellReserveButton' => l10n?.shellReserveButton ?? 'Reserve',
      'planReserveButton' => l10n?.planReserveButton ?? 'Reserve',
      'levelReserveButton' => l10n?.levelReserveButton ?? 'Reserve level',
      'planMorningChip' => l10n?.planMorningChip ?? 'Morning',
      'planAfternoonChip' => l10n?.planAfternoonChip ?? 'Afternoon',
      'planFromLabel' => l10n?.planFromLabel ?? 'From',
      'planDurationLabel' => l10n?.planDurationLabel ?? 'Duration',
      'planBookForLabel' => l10n?.planBookForLabel ?? 'For',
      'planCheckInTitle' => l10n?.planCheckInTitle ?? 'Check in',
      'planCheckInButton' => l10n?.planCheckInButton ?? 'Check in',
      'reserveMonthView' => l10n?.reserveMonthView ?? 'Month',
      'reserveDayView' => l10n?.reserveDayView ?? 'Day',
      'reserveWeekView' => l10n?.reserveWeekView ?? 'Week',
      'reserveFullDayChip' => l10n?.reserveFullDayChip ?? 'Full day',
      _ => key,
    };

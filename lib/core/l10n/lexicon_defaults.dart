// SPDX-License-Identifier: AGPL-3.0-or-later
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
String lexiconDefault(AppLocalizations l10n, String key) => switch (key) {
      'legendFree' => l10n.legendFree,
      'legendReserved' => l10n.legendReserved,
      'legendOccupied' => l10n.legendOccupied,
      'legendMine' => l10n.legendMine,
      'legendBlocked' => l10n.legendBlocked,
      'legendClosed' => l10n.legendClosed,
      'legendUnavailable' => l10n.legendUnavailable,
      'reserveClosedShort' => l10n.reserveClosedShort,
      'spaceKindSeat' => l10n.spaceKindSeat,
      'spaceKindDesk' => l10n.spaceKindDesk,
      'spaceKindOffice' => l10n.spaceKindOffice,
      'spaceKindLevel' => l10n.spaceKindLevel,
      'levelDetail' => l10n.levelDetail,
      'deskDetail' => l10n.deskDetail,
      'tabPlan' => l10n.tabPlan,
      'tabCalendar' => l10n.tabCalendar,
      'tabEvents' => l10n.tabEvents,
      'tabMoney' => l10n.tabMoney,
      'directoryTitle' => l10n.directoryTitle,
      'messagesTitle' => l10n.messagesTitle,
      'shellReserveButton' => l10n.shellReserveButton,
      'planReserveButton' => l10n.planReserveButton,
      'levelReserveButton' => l10n.levelReserveButton,
      'planMorningChip' => l10n.planMorningChip,
      'planAfternoonChip' => l10n.planAfternoonChip,
      'planFromLabel' => l10n.planFromLabel,
      'planDurationLabel' => l10n.planDurationLabel,
      'planBookForLabel' => l10n.planBookForLabel,
      'planCheckInTitle' => l10n.planCheckInTitle,
      'planCheckInButton' => l10n.planCheckInButton,
      'reserveMonthView' => l10n.reserveMonthView,
      'reserveDayView' => l10n.reserveDayView,
      'reserveWeekView' => l10n.reserveWeekView,
      'reserveFullDayChip' => l10n.reserveFullDayChip,
      _ => key,
    };

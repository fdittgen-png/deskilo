// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/widgets.dart';

/// Where a term shows up, so the editor can browse by surface rather
/// than by key — and so that two keys sharing an English word
/// (`shellReserveButton`/`planReserveButton`, both "Reserve") are
/// distinguishable to the person renaming them.
enum LexiconSurface { legend, plan, navigation, booking }

/// One overridable product term.
class LexiconTerm {
  const LexiconTerm(this.surface, {this.placeholders = const []});

  final LexiconSurface surface;

  /// The `{token}` names the override MUST carry, exactly. Every term is
  /// tokenless today; the rule exists before the first key that needs
  /// one, and the server enforces the same comparison (0223).
  final List<String> placeholders;
}

/// The allow-list, mirroring `lexicon_allowed_keys()` in 0223.
///
/// `lexicon_allow_list_test` pins this against the migration, so the
/// editor can never offer a key the server would refuse, and the server
/// can never allow one the app does not render.
const Map<String, LexiconTerm> lexiconAllowList = {
  // the plan legend
  'legendFree': LexiconTerm(LexiconSurface.legend),
  'legendReserved': LexiconTerm(LexiconSurface.legend),
  'legendOccupied': LexiconTerm(LexiconSurface.legend),
  'legendMine': LexiconTerm(LexiconSurface.legend),
  'legendBlocked': LexiconTerm(LexiconSurface.legend),
  'legendClosed': LexiconTerm(LexiconSurface.legend),
  // #1281's simple profile says one word for blocked AND closed; #1597
  // registered it, because the legend rendered it before any list knew.
  'legendUnavailable': LexiconTerm(LexiconSurface.legend),
  'reserveClosedShort': LexiconTerm(LexiconSurface.legend),
  // what a space is made of
  'spaceKindSeat': LexiconTerm(LexiconSurface.plan),
  'spaceKindDesk': LexiconTerm(LexiconSurface.plan),
  'spaceKindOffice': LexiconTerm(LexiconSurface.plan),
  'spaceKindLevel': LexiconTerm(LexiconSurface.plan),
  'levelDetail': LexiconTerm(LexiconSurface.plan),
  'deskDetail': LexiconTerm(LexiconSurface.plan),
  // the shell's destinations
  'tabPlan': LexiconTerm(LexiconSurface.navigation),
  'tabCalendar': LexiconTerm(LexiconSurface.navigation),
  'tabEvents': LexiconTerm(LexiconSurface.navigation),
  'tabMoney': LexiconTerm(LexiconSurface.navigation),
  'directoryTitle': LexiconTerm(LexiconSurface.navigation),
  'messagesTitle': LexiconTerm(LexiconSurface.navigation),
  // reserving
  'shellReserveButton': LexiconTerm(LexiconSurface.booking),
  'planReserveButton': LexiconTerm(LexiconSurface.booking),
  'levelReserveButton': LexiconTerm(LexiconSurface.booking),
  'planMorningChip': LexiconTerm(LexiconSurface.booking),
  'planAfternoonChip': LexiconTerm(LexiconSurface.booking),
  'planFromLabel': LexiconTerm(LexiconSurface.booking),
  'planDurationLabel': LexiconTerm(LexiconSurface.booking),
  'planBookForLabel': LexiconTerm(LexiconSurface.booking),
  'planCheckInTitle': LexiconTerm(LexiconSurface.booking),
  'planCheckInButton': LexiconTerm(LexiconSurface.booking),
  'reserveMonthView': LexiconTerm(LexiconSurface.booking),
  'reserveDayView': LexiconTerm(LexiconSurface.booking),
  'reserveWeekView': LexiconTerm(LexiconSurface.booking),
  'reserveFullDayChip': LexiconTerm(LexiconSurface.booking),
};

/// #1277 — a workspace's own words for allow-listed product terms.
///
/// An association calls a seat «une place»; a space with private offices
/// calls a desk «un poste». The product's word is an ARB key resolved at
/// build time, so without this there is exactly one word per locale.
///
/// ## Why an allow-list and not a general mechanism
///
/// There are 3 046 ARB keys × 5 locales. Re-templating them around
/// abstract terms was rejected on cost, and wrapping `AppLocalizations`
/// would mean a delegating class with 3 046 members. Instead a declared
/// set of PRODUCT TERMINOLOGY may be overridden — the legend labels, the
/// space nouns, the shell destinations, the booking sheet's own words.
///
/// The allow-list is the security boundary as much as the design one: a
/// workspace may rename a seat and may NOT rewrite an error message, a
/// legal mention or a confirmation, because those keys are not in it.
/// The server enforces the same list in `lexicon_allowed_keys()` (0223);
/// `lexicon_allow_list_test` pins the two together, so the editor can
/// never offer a key the server would refuse.
///
/// ## Ambient, like the working day
///
/// Resolving a word must work in a `build()` that has no `ref` — the
/// legend, the shell bar and the booking sheet all render deep inside
/// widgets that were never given one. So the active workspace's map is
/// INSTALLED, exactly as [WorkHours] installs the working day: the shell
/// installs it on connect and on profile switch, and the kiosk installs
/// it on its own route.
///
/// The consequence to respect: this is global mutable state. A workspace
/// that has said nothing installs an empty map, and [text] then returns
/// the fallback — which is the product's own translated string, so a
/// space with no overrides renders exactly as it did before this
/// existed.
abstract final class Lexicon {
  /// locale → key → the workspace's word.
  static Map<String, Map<String, String>> _current = const {};

  /// The ambient overrides (empty until a workspace installed its own).
  static Map<String, Map<String, String>> get current => _current;

  /// Installs [raw] — the `workspaces.lexicon` jsonb as it arrives from
  /// the server, `{locale: {key: text}}`. Null or malformed restores the
  /// empty map rather than throwing: a bad row must not take the app
  /// down, it must render the product's own words.
  static void install(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      _current = const {};
      return;
    }
    final parsed = <String, Map<String, String>>{};
    for (final entry in raw.entries) {
      final terms = entry.value;
      if (terms is! Map) continue;
      final byKey = <String, String>{};
      for (final term in terms.entries) {
        final value = term.value;
        // Only strings, and never an empty one: an empty override would
        // render as a blank label, which is worse than the default.
        if (value is String && value.isNotEmpty) {
          byKey['${term.key}'] = value;
        }
      }
      if (byKey.isNotEmpty) parsed[entry.key] = byKey;
    }
    _current = parsed;
  }

  /// Back to no overrides (tests, sign-out, profile switch).
  static void reset() => _current = const {};

  /// The workspace's word for [key] in [locale], or null if it has none.
  static String? term(String locale, String key) => _current[locale]?[key];
}

/// The workspace's word for [key], or [fallback] — which is the
/// product's own localized string.
///
/// Call sites read:
///
/// ```dart
/// lexiconText(context, key: 'legendFree', fallback: l10n?.legendFree ?? 'Free')
/// ```
///
/// The fallback stays a full `AppLocalizations` lookup on purpose. It is
/// what renders for every workspace that has overridden nothing — which
/// is almost all of them — so it must be the translated string and not
/// an English constant.
///
/// The locale is the one the app is rendering in, not the workspace's
/// default: a German-speaking member of a French space reads the German
/// overrides if the space wrote any, and the German product strings
/// otherwise.
/// [context] is nullable on purpose. Some of these terms are rendered by
/// PURE functions — `bookingRangeText` formats "Full day · 09:00 – 17:00"
/// and is unit-tested with a constructed `AppFormat` and no widget tree
/// at all. Forcing a context on them would mean pumping a widget to test
/// string formatting, which is a worse test for no gain.
///
/// A null context means no locale, so no override, so the product's own
/// word — which is exactly what a workspace that renamed nothing gets.
/// The parameter stays REQUIRED and positional even though it is
/// nullable: a widget call site that silently omitted it would disable
/// overrides on that surface invisibly, and passing `null` should be a
/// statement rather than an oversight.
String lexiconText(
  BuildContext? context, {
  required String key,
  required String fallback,
}) {
  if (context == null) return fallback;
  return Lexicon.term(Localizations.localeOf(context).languageCode, key) ??
      fallback;
}

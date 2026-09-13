// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/workspace_feature.dart';

/// #1221 — where a feature shows up, named the way the app names it.
///
/// The Features screen used to group by TIER, which answers "should a
/// space like mine have this" — a fair question, and not the one an
/// owner arrives with. They arrive having seen something on a screen,
/// or wanting something to appear on one. So the grouping is the place,
/// and the tier survives as a chip on the row.
String featureSurfaceName(AppLocalizations? l10n, FeatureSurface surface) =>
    switch (surface) {
      FeatureSurface.reserve => l10n?.shellReserveButton ?? 'Reserve',
      FeatureSurface.calendar => l10n?.tabCalendar ?? 'Calendar',
      FeatureSurface.members => l10n?.membersTitle ?? 'Members',
      FeatureSurface.money => l10n?.tabMoney ?? 'Money',
      FeatureSurface.messages => l10n?.messagesTitle ?? 'Messages',
      FeatureSurface.documents => l10n?.documentsTitle ?? 'Documents',
      FeatureSurface.kiosk => l10n?.kioskRevertTitle ?? 'Kiosk device',
      FeatureSurface.reports => l10n?.featureSurfaceReports ?? 'Documents you print',
      FeatureSurface.settings => l10n?.settingsTitle ?? 'Settings',
      FeatureSurface.everywhere =>
        l10n?.featureSurfaceEverywhere ?? 'The whole app',
    };

/// One line under the heading saying what that part of the app is, so
/// the group is a place rather than a word.
String featureSurfaceHint(AppLocalizations? l10n, FeatureSurface surface) =>
    switch (surface) {
      FeatureSurface.reserve => l10n?.featureSurfaceReserveHint ??
          'Booking a seat, the floor plan, check-in.',
      FeatureSurface.calendar => l10n?.featureSurfaceCalendarHint ??
          'What is happening, by day and by month.',
      FeatureSurface.members => l10n?.featureSurfaceMembersHint ??
          'Who is in the space, their profiles and their roles.',
      FeatureSurface.money => l10n?.featureSurfaceMoneyHint ??
          'Statements, payments, invoices and what they are made of.',
      FeatureSurface.messages => l10n?.featureSurfaceMessagesHint ??
          'Conversations, alerts and what reaches a phone.',
      FeatureSurface.documents => l10n?.featureSurfaceDocumentsHint ??
          'The files the space keeps and shares.',
      FeatureSurface.kiosk => l10n?.featureSurfaceKioskHint ??
          'The tablet at the door, badges and scanning.',
      FeatureSurface.reports => l10n?.featureSurfaceReportsHint ??
          'Invoices, statements and letters, and how they look on paper.',
      FeatureSurface.settings => l10n?.featureSurfaceSettingsHint ??
          'How the space itself is set up.',
      FeatureSurface.everywhere => l10n?.featureSurfaceEverywhereHint ??
          'Changes how the app behaves, wherever you are in it.',
    };

IconData featureSurfaceIcon(FeatureSurface surface) => switch (surface) {
      FeatureSurface.reserve => Icons.event_seat_outlined,
      FeatureSurface.calendar => Icons.calendar_month_outlined,
      FeatureSurface.members => Icons.people_outline,
      FeatureSurface.money => Icons.account_balance_wallet_outlined,
      FeatureSurface.messages => Icons.forum_outlined,
      FeatureSurface.documents => Icons.folder_open_outlined,
      FeatureSurface.kiosk => Icons.tablet_android_outlined,
      FeatureSurface.reports => Icons.description_outlined,
      FeatureSurface.settings => Icons.settings_outlined,
      FeatureSurface.everywhere => Icons.apps_outlined,
    };

/// The first sentence of a description — what the feature IS — split
/// from the rest, which is how it behaves in detail (#1221).
///
/// The descriptions average 158 characters and run to 390, so the
/// screen was a wall of prose you scrolled past rather than read. The
/// lead sentence is the answer to "what is this"; everything after it
/// is the answer to "how exactly", which is a question you only have
/// about the one you stopped on.
({String lead, String rest}) splitFeatureDescription(String description) {
  final text = description.trim();
  // A sentence ends at '. ' — not at a decimal point, an ellipsis or an
  // abbreviation, none of which are followed by a space and a capital.
  final match = RegExp(r'[.!?]\s+(?=[A-ZÀ-ÖØ-Þ«"])').firstMatch(text);
  if (match == null) return (lead: text, rest: '');
  final lead = text.substring(0, match.start + 1);
  final rest = text.substring(match.end).trim();
  // A one-word tail is not worth a disclosure control.
  if (rest.length < 24) return (lead: text, rest: '');
  return (lead: lead, rest: rest);
}

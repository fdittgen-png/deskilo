// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — moved whole from member_page.dart so the directory's chips use
// it without embedding the member page.
import '../../../l10n/app_localizations.dart';

/// "Seen 20 h ago" — the directory's relative last-seen label, shared
/// with the row chip (#825: it now says what the number means).
String relativeLastSeen(
  AppLocalizations l10n,
  DateTime now,
  DateTime lastSeenAt,
) {
  final diff = now.difference(lastSeenAt);
  if (diff.inMinutes < 60) {
    final minutes = diff.inMinutes < 1 ? 1 : diff.inMinutes;
    return l10n.directoryLastSeenMinutes(minutes);
  }
  if (diff.inHours < 24) {
    final hours = diff.inHours;
    return l10n.directoryLastSeenHours(hours);
  }
  final days = diff.inDays;
  return l10n.directoryLastSeenDays(days);
}

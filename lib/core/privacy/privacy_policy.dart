// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../l10n/app_localizations.dart';

/// #751 — the consent the app asks for before anything else, and shows
/// again on demand (Settings → Privacy & data, the in-app help, the
/// guide site, privacy.html). Bump [kPrivacyPolicyVersion] whenever the TEXT
/// changes: every account is then asked again, once.
const kPrivacyPolicyVersion = '2026-10-10';

/// Where the same text lives outside the app: its section of the published
/// user guide (the guide site's element id is the section's anchor).
const kPrivacyGuideUrl =
    'https://fdittgen-png.github.io/deskilo/guide/en.html#user.privacy.consent';

/// One section of the consent text: a heading and its paragraph.
class PrivacySection {
  const PrivacySection(this.title, this.body);
  final String title;
  final String body;
}

/// The consent text, localized, in reading order. The English fallback
/// is the text of record; the ARB fragments carry the four translations.
List<PrivacySection> privacySections(AppLocalizations l10n) => [
      PrivacySection(
        l10n.consentWhatTitle,
        l10n.consentWhatBody,
      ),
      PrivacySection(
        l10n.consentNotTitle,
        l10n.consentNotBody,
      ),
      PrivacySection(
        l10n.consentWhoTitle,
        l10n.consentWhoBody,
      ),
      PrivacySection(
        l10n.consentMessagesTitle,
        l10n.consentMessagesBody,
      ),
      PrivacySection(
        l10n.consentPushTitle,
        l10n.consentPushBody,
      ),
      PrivacySection(
        l10n.consentControllerTitle,
        l10n.consentControllerBody,
      ),
      PrivacySection(
        l10n.consentRetentionTitle,
        l10n.consentRetentionBody,
      ),
      PrivacySection(
        l10n.consentRightsTitle,
        l10n.consentRightsBody,
      ),
      PrivacySection(
        l10n.consentReviewTitle,
        l10n.consentReviewBody,
      ),
    ];
